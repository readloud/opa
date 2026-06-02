import {
  WebSocketGateway,
  WebSocketServer,
  SubscribeMessage,
  ConnectedSocket,
  MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { UseGuards } from '@nestjs/common';
import { DroneService } from './drone.service';
import { WsJwtGuard } from '../../common/guards/ws-jwt.guard';

@WebSocketGateway({
  cors: { origin: '*' },
  namespace: '/drone',
})
export class DroneGateway {
  @WebSocketServer()
  server: Server;

  private activeStreams: Map<string, { socketId: string; interval: NodeJS.Timeout }> = new Map();

  constructor(private droneService: DroneService) {}

  @SubscribeMessage('drone:connect')
  async handleDroneConnect(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const { droneId, estateId } = data;
    client.data.droneId = droneId;
    client.data.estateId = estateId;
    
    client.join(`drone:${droneId}`);
    client.join(`estate:${estateId}`);
    
    client.emit('drone:connected', { status: 'connected', droneId });
    
    // Start streaming telemetry
    this.startTelemetryStream(client, droneId);
  }

  @SubscribeMessage('drone:start-stream')
  async handleStartStream(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const { missionId } = data;
    const streamId = `${client.data.droneId}:${missionId}`;
    
    // Simulate real-time video stream
    const interval = setInterval(() => {
      this.server.to(`drone:${client.data.droneId}`).emit('drone:frame', {
        timestamp: new Date(),
        imageData: this.generateMockFrame(),
        position: {
          lat: -6.2088 + (Math.random() - 0.5) * 0.01,
          lng: 106.8456 + (Math.random() - 0.5) * 0.01,
          altitude: 50 + Math.random() * 30,
        },
      });
    }, 1000);
    
    this.activeStreams.set(streamId, { socketId: client.id, interval });
    
    client.emit('drone:stream-started', { streamId });
  }

  @SubscribeMessage('drone:stop-stream')
  handleStopStream(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const { streamId } = data;
    const stream = this.activeStreams.get(streamId);
    
    if (stream) {
      clearInterval(stream.interval);
      this.activeStreams.delete(streamId);
    }
    
    client.emit('drone:stream-stopped', { streamId });
  }

  @SubscribeMessage('drone:telemetry')
  handleTelemetry(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    // Store telemetry data
    const { battery, gps, sensors } = data;
    
    client.emit('drone:telemetry-ack', { timestamp: new Date() });
    
    // Broadcast to subscribers
    this.server.to(`estate:${client.data.estateId}`).emit('drone:telemetry-update', {
      droneId: client.data.droneId,
      battery,
      gps,
      sensors,
      timestamp: new Date(),
    });
  }

  @SubscribeMessage('drone:mission-status')
  async handleMissionStatus(
    @ConnectedSocket() client: Socket,
    @MessageBody() data: any,
  ) {
    const { missionId, status, progress } = data;
    
    await this.droneService.updateMissionStatus(missionId, status, progress);
    
    this.server.to(`estate:${client.data.estateId}`).emit('drone:mission-update', {
      missionId,
      status,
      progress,
      timestamp: new Date(),
    });
  }

  private startTelemetryStream(client: Socket, droneId: string) {
    const interval = setInterval(() => {
      if (client.connected) {
        client.emit('drone:telemetry', {
          droneId,
          battery: 70 + Math.random() * 20,
          gps: {
            lat: -6.2088 + (Math.random() - 0.5) * 0.01,
            lng: 106.8456 + (Math.random() - 0.5) * 0.01,
            satellites: 8 + Math.floor(Math.random() * 7),
          },
          sensors: {
            temperature: 25 + Math.random() * 10,
            humidity: 60 + Math.random() * 30,
            pressure: 1010 + Math.random() * 20,
          },
          speed: 5 + Math.random() * 10,
          altitude: 30 + Math.random() * 70,
        });
      }
    }, 2000);
    
    client.on('disconnect', () => {
      clearInterval(interval);
    });
  }

  private generateMockFrame(): string {
    // In production, this would be actual video frame
    // Return base64 encoded mock frame
    return 'data:image/jpeg;base64,...';
  }
}