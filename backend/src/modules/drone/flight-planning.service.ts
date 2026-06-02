import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.module';
import axios from 'axios';

@Injectable()
export class FlightPlanningService {
  private readonly logger = new Logger(FlightPlanningService.name);
  private readonly API_KEY = process.env.OPENWEATHER_API_KEY;

  constructor(private prisma: PrismaService) {}

  async getOptimalFlightTime(lat: number, lon: number, dateRange: { start: Date; end: Date }) {
    const forecast = await this.getWeatherForecast(lat, lon, 7);
    
    const optimalSlots = [];
    
    for (const day of forecast) {
      for (const hour of day.hourly) {
        const score = this.calculateFlightScore(hour);
        
        if (score > 70) {
          optimalSlots.push({
            datetime: hour.datetime,
            score,
            conditions: {
              windSpeed: hour.windSpeed,
              visibility: hour.visibility,
              cloudCover: hour.cloudCover,
              precipitation: hour.precipitation,
            },
          });
        }
      }
    }
    
    // Sort by score
    optimalSlots.sort((a, b) => b.score - a.score);
    
    // Save optimal schedule
    if (optimalSlots.length > 0) {
      await this.saveOptimalSchedule(lat, lon, optimalSlots[0]);
    }
    
    return {
      optimalSlots: optimalSlots.slice(0, 10),
      bestSlot: optimalSlots[0],
      recommendations: this.generateRecommendations(optimalSlots[0]),
    };
  }

  private async getWeatherForecast(lat: number, lon: number, days: number) {
    const response = await axios.get(
      `https://api.openweathermap.org/data/3.0/onecall`,
      {
        params: {
          lat,
          lon,
          appid: this.API_KEY,
          units: 'metric',
          exclude: 'current,minutely,alerts',
        },
      }
    );
    
    const forecast = [];
    const hourly = response.data.hourly;
    
    for (let i = 0; i < Math.min(hourly.length, days * 24); i++) {
      const hour = hourly[i];
      const dt = new Date(hour.dt * 1000);
      
      forecast.push({
        datetime: dt,
        temperature: hour.temp,
        windSpeed: hour.wind_speed,
        windGust: hour.wind_gust,
        humidity: hour.humidity,
        cloudCover: hour.clouds,
        visibility: hour.visibility / 1000, // km
        precipitation: hour.rain?.['1h'] || 0,
        weather: hour.weather[0].description,
      });
    }
    
    return this.groupByDay(forecast);
  }

  private groupByDay(forecast: any[]): any[] {
    const days: Record<string, any> = {};
    
    for (const hour of forecast) {
      const dateKey = hour.datetime.toISOString().split('T')[0];
      if (!days[dateKey]) {
        days[dateKey] = { date: dateKey, hourly: [] };
      }
      days[dateKey].hourly.push(hour);
    }
    
    return Object.values(days);
  }

  private calculateFlightScore(condition: any): number {
    let score = 100;
    
    // Wind penalty (optimal < 15 km/h)
    if (condition.windSpeed > 30) score -= 50;
    else if (condition.windSpeed > 20) score -= 30;
    else if (condition.windSpeed > 15) score -= 15;
    else if (condition.windSpeed < 5) score -= 5; // Too calm for good overlap
    
    // Rain penalty
    if (condition.precipitation > 5) score -= 100;
    else if (condition.precipitation > 2) score -= 50;
    else if (condition.precipitation > 0.5) score -= 20;
    
    // Visibility penalty (optimal > 10 km)
    if (condition.visibility < 2) score -= 50;
    else if (condition.visibility < 5) score -= 25;
    else if (condition.visibility < 8) score -= 10;
    
    // Cloud cover penalty (optimal < 30%)
    if (condition.cloudCover > 80) score -= 30;
    else if (condition.cloudCover > 60) score -= 15;
    else if (condition.cloudCover > 40) score -= 5;
    
    return Math.max(0, score);
  }

  private generateRecommendations(bestSlot: any): string[] {
    const recommendations = [];
    
    if (bestSlot) {
      recommendations.push(`Waktu terbaik: ${bestSlot.datetime.toLocaleString()}`);
      
      if (bestSlot.conditions.windSpeed > 15) {
        recommendations.push('Kecepatan angin cukup tinggi. Gunakan mode stabilisasi.');
      }
      
      if (bestSlot.conditions.cloudCover > 60) {
        recommendations.push('Tutupan awan tinggi. Pastikan pencahayaan cukup.');
      }
      
      if (bestSlot.conditions.visibility < 8) {
        recommendations.push('Visibilitas terbatas. Terbang dengan kecepatan lebih rendah.');
      }
    }
    
    return recommendations;
  }

  private async saveOptimalSchedule(lat: number, lon: number, bestSlot: any) {
    await this.prisma.flightSchedule.create({
      data: {
        latitude: lat,
        longitude: lon,
        scheduledTime: bestSlot.datetime,
        weatherConditions: bestSlot.conditions,
        status: 'PENDING',
      },
    });
  }

  async getFlightSchedules(estateId: string) {
    const estate = await this.prisma.estate.findUnique({
      where: { id: estateId },
    });
    
    if (!estate) return [];
    
    // Get geometry center for weather
    let lat = -6.2088, lon = 106.8456;
    if (estate.geometry) {
      const geom = estate.geometry as any;
      if (geom.coordinates && geom.coordinates[0]) {
        const coords = geom.coordinates[0][0];
        lat = coords[1];
        lon = coords[0];
      }
    }
    
    const optimal = await this.getOptimalFlightTime(lat, lon, {
      start: new Date(),
      end: new Date(Date.now() + 7 * 24 * 60 * 60 * 1000),
    });
    
    return {
      currentWeather: await this.getCurrentWeather(lat, lon),
      optimalSchedule: optimal,
      existingSchedules: await this.prisma.flightSchedule.findMany({
        where: { status: 'PENDING' },
        orderBy: { scheduledTime: 'asc' },
      }),
    };
  }

  private async getCurrentWeather(lat: number, lon: number) {
    const response = await axios.get(
      `https://api.openweathermap.org/data/2.5/weather`,
      {
        params: {
          lat,
          lon,
          appid: this.API_KEY,
          units: 'metric',
        },
      }
    );
    
    return {
      temperature: response.data.main.temp,
      humidity: response.data.main.humidity,
      windSpeed: response.data.wind.speed,
      windDirection: response.data.wind.deg,
      weather: response.data.weather[0].description,
      visibility: response.data.visibility / 1000,
    };
  }
}