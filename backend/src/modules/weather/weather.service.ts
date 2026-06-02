import { Injectable, Logger } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import axios from 'axios';

@Injectable()
export class WeatherService {
  private readonly logger = new Logger(WeatherService.name);
  private readonly API_KEY = process.env.OPENWEATHER_API_KEY;
  private readonly BASE_URL = 'https://api.openweathermap.org/data/2.5';

  constructor(private prisma: PrismaService) {}

  async getCurrentWeather(lat: number, lon: number) {
    const response = await axios.get(`${this.BASE_URL}/weather`, {
      params: {
        lat,
        lon,
        appid: this.API_KEY,
        units: 'metric',
        lang: 'id',
      },
    });

    return {
      temperature: response.data.main.temp,
      feelsLike: response.data.main.feels_like,
      humidity: response.data.main.humidity,
      pressure: response.data.main.pressure,
      weather: response.data.weather[0].description,
      icon: response.data.weather[0].icon,
      windSpeed: response.data.wind.speed,
      rain: response.data.rain?.['1h'] || 0,
      timestamp: new Date(),
    };
  }

  async getForecast(lat: number, lon: number, days: number = 7) {
    const response = await axios.get(`${this.BASE_URL}/forecast`, {
      params: {
        lat,
        lon,
        appid: this.API_KEY,
        units: 'metric',
        lang: 'id',
        cnt: days * 8, // 3-hour intervals
      },
    });

    const forecasts = [];
    const dailyData = new Map();

    for (const item of response.data.list) {
      const date = new Date(item.dt * 1000);
      const dateKey = date.toISOString().split('T')[0];
      
      if (!dailyData.has(dateKey)) {
        dailyData.set(dateKey, []);
      }
      dailyData.get(dateKey).push(item);
    }

    for (const [date, items] of dailyData.entries()) {
      const temps = items.map(i => i.main.temp);
      const rains = items.map(i => i.rain?.['3h'] || 0);
      
      forecasts.push({
        date,
        temperature: {
          min: Math.min(...temps),
          max: Math.max(...temps),
          avg: temps.reduce((a, b) => a + b, 0) / temps.length,
        },
        humidity: items[0].main.humidity,
        rain: rains.reduce((a, b) => a + b, 0),
        weather: items[0].weather[0].description,
        icon: items[0].weather[0].icon,
        windSpeed: items[0].wind.speed,
      });
    }

    return forecasts.slice(0, days);
  }

  async predictHarvestYield(estateId: string, blockId?: string) {
    const where: any = { estateId };
    if (blockId) where.id = blockId;

    const blocks = await this.prisma.block.findMany({
      where,
      include: {
        harvests: {
          orderBy: { harvestDate: 'desc' },
          take: 12, // Last 12 harvests
        },
        weatherData: {
          orderBy: { date: 'desc' },
          take: 30,
        },
      },
    });

    const predictions = [];

    for (const block of blocks) {
      // Get weather forecast
      const geometry = block.geometry as any;
      let lat, lon;
      
      if (geometry && geometry.coordinates) {
        const coords = geometry.coordinates[0][0];
        lat = coords[1];
        lon = coords[0];
      } else {
        // Default coordinates
        lat = -6.2088;
        lon = 106.8456;
      }

      const forecast = await this.getForecast(lat, lon, 14);
      
      // Calculate historical average yield
      const historicalYields = block.harvests.map(h => h.tonase);
      const avgYield = historicalYields.length > 0
        ? historicalYields.reduce((a, b) => a + b, 0) / historicalYields.length
        : 0;
      
      // Weather impact coefficients
      const impact = this.calculateWeatherImpact(forecast);
      
      // Predict yield for next 14 days
      const dailyPredictions = forecast.map(day => ({
        date: day.date,
        predictedYield: avgYield * (1 + impact[day.date] / 100),
        weather: day.weather,
        temperature: day.temperature.avg,
        rain: day.rain,
        confidence: this.calculateConfidence(historicalYields.length, day),
      }));

      predictions.push({
        blockId: block.id,
        blockName: block.name,
        historicalAvgYield: avgYield,
        totalPredictedYield: dailyPredictions.reduce((sum, p) => sum + p.predictedYield, 0),
        dailyPredictions,
      });
    }

    return predictions;
  }

  private calculateWeatherImpact(forecast: any[]): Record<string, number> {
    const impact: Record<string, number> = {};
    
    for (const day of forecast) {
      let impactPercent = 0;
      
      // Temperature impact (optimal 26-28°C)
      const temp = day.temperature.avg;
      if (temp < 24) impactPercent -= (24 - temp) * 5;
      else if (temp > 32) impactPercent -= (temp - 32) * 8;
      else if (temp >= 26 && temp <= 28) impactPercent += 10;
      
      // Rain impact (optimal 150-200mm/week)
      const weeklyRain = day.rain;
      if (weeklyRain < 100) impactPercent -= (100 - weeklyRain) * 0.5;
      else if (weeklyRain > 300) impactPercent -= (weeklyRain - 300) * 0.3;
      else if (weeklyRain >= 150 && weeklyRain <= 200) impactPercent += 15;
      
      // Humidity impact (optimal 70-80%)
      const humidity = day.humidity;
      if (humidity < 50) impactPercent -= (50 - humidity) * 0.5;
      else if (humidity > 90) impactPercent -= (humidity - 90) * 0.8;
      else if (humidity >= 70 && humidity <= 80) impactPercent += 5;
      
      impact[day.date] = Math.max(-50, Math.min(50, impactPercent));
    }
    
    return impact;
  }

  private calculateConfidence(historicalDataPoints: number, day: any): number {
    let confidence = 70; // Base confidence
    
    // More historical data = higher confidence
    confidence += Math.min(20, historicalDataPoints / 10);
    
    // Lower confidence for far future
    const daysAhead = Math.ceil((new Date(day.date).getTime() - new Date().getTime()) / (1000 * 3600 * 24));
    confidence -= daysAhead * 2;
    
    // Adjust based on weather certainty
    if (day.weather.includes('hujan')) confidence -= 10;
    if (day.weather.includes('cerah')) confidence += 5;
    
    return Math.max(30, Math.min(95, confidence));
  }

  async getWeatherAlert(estateId: string) {
    const blocks = await this.prisma.block.findMany({
      where: { estateId },
    });

    const alerts = [];

    for (const block of blocks) {
      const geometry = block.geometry as any;
      let lat, lon;
      
      if (geometry && geometry.coordinates) {
        const coords = geometry.coordinates[0][0];
        lat = coords[1];
        lon = coords[0];
      } else {
        lat = -6.2088;
        lon = 106.8456;
      }

      const forecast = await this.getForecast(lat, lon, 3);
      
      for (const day of forecast) {
        if (day.rain > 50) {
          alerts.push({
            type: 'HEAVY_RAIN',
            blockName: block.name,
            date: day.date,
            severity: day.rain > 100 ? 'HIGH' : 'MEDIUM',
            message: `Hujan lebat diperkirakan pada ${day.date} di ${block.name} (${day.rain}mm)`,
          });
        }
        
        if (day.temperature.max > 35) {
          alerts.push({
            type: 'HEATWAVE',
            blockName: block.name,
            date: day.date,
            severity: 'HIGH',
            message: `Suhu tinggi (>35°C) diperkirakan pada ${day.date} di ${block.name}`,
          });
        }
      }
    }

    return alerts;
  }

  async saveWeatherData(estateId: string, lat: number, lon: number) {
    const current = await this.getCurrentWeather(lat, lon);
    
    await this.prisma.weatherData.create({
      data: {
        estateId,
        date: new Date(),
        temperature: current.temperature,
        humidity: current.humidity,
        rainfall: current.rain,
        windSpeed: current.windSpeed,
        weatherCondition: current.weather,
      },
    });
    
    return current;
  }
}