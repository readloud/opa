import { Injectable, BadRequestException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as AWS from 'aws-sdk';
import { v4 as uuidv4 } from 'uuid';
import * as sharp from 'sharp';
import { Readable } from 'stream';

@Injectable()
export class StorageService {
  private s3: AWS.S3;
  private bucket: string;
  private useMinio: boolean;

  constructor(private configService: ConfigService) {
    const endpoint = this.configService.get('S3_ENDPOINT');
    this.useMinio = !!endpoint;
    
    this.s3 = new AWS.S3({
      accessKeyId: this.configService.get('AWS_ACCESS_KEY_ID'),
      secretAccessKey: this.configService.get('AWS_SECRET_ACCESS_KEY'),
      region: this.configService.get('AWS_REGION'),
      endpoint: endpoint || undefined,
      s3ForcePathStyle: this.useMinio,
      signatureVersion: 'v4',
    });
    
    this.bucket = this.configService.get('AWS_S3_BUCKET');
  }

  async uploadImage(
    file: Express.Multer.File,
    folder: string = 'inspections',
    userId: string,
  ): Promise<string> {
    if (!file.mimetype.startsWith('image/')) {
      throw new BadRequestException('File must be an image');
    }

    // Compress image
    const compressedBuffer = await this.compressImage(file.buffer, file.mimetype);
    
    // Generate filename
    const extension = file.mimetype.split('/')[1];
    const filename = `${folder}/${userId}/${uuidv4()}.${extension}`;
    
    // Upload to S3
    const uploadParams: AWS.S3.PutObjectRequest = {
      Bucket: this.bucket,
      Key: filename,
      Body: compressedBuffer,
      ContentType: file.mimetype,
      CacheControl: 'max-age=31536000', // 1 year cache
    };
    
    await this.s3.upload(uploadParams).promise();
    
    // Return public URL
    if (this.useMinio) {
      return `${this.configService.get('S3_PUBLIC_URL')}/${this.bucket}/${filename}`;
    }
    return `https://${this.bucket}.s3.${this.configService.get('AWS_REGION')}.amazonaws.com/${filename}`;
  }

  async uploadMultipleImages(
    files: Express.Multer.File[],
    folder: string = 'inspections',
    userId: string,
  ): Promise<string[]> {
    const uploadPromises = files.map(file => this.uploadImage(file, folder, userId));
    return Promise.all(uploadPromises);
  }

  private async compressImage(buffer: Buffer, mimeType: string): Promise<Buffer> {
    let sharpInstance = sharp(buffer);
    
    // Resize if too large (max 1200px width/height)
    const metadata = await sharpInstance.metadata();
    const maxDimension = 1200;
    
    if (metadata.width && metadata.width > maxDimension) {
      sharpInstance = sharpInstance.resize(maxDimension, null, {
        fit: 'inside',
        withoutEnlargement: true,
      });
    }
    
    // Compress based on format
    if (mimeType === 'image/jpeg' || mimeType === 'image/jpg') {
      return sharpInstance.jpeg({ quality: 80, progressive: true }).toBuffer();
    } else if (mimeType === 'image/png') {
      return sharpInstance.png({ quality: 80, compressionLevel: 9 }).toBuffer();
    } else if (mimeType === 'image/webp') {
      return sharpInstance.webp({ quality: 80 }).toBuffer();
    }
    
    return buffer;
  }

  async deleteImage(imageUrl: string): Promise<void> {
    // Extract key from URL
    const key = this.extractKeyFromUrl(imageUrl);
    if (!key) return;
    
    const deleteParams: AWS.S3.DeleteObjectRequest = {
      Bucket: this.bucket,
      Key: key,
    };
    
    await this.s3.deleteObject(deleteParams).promise();
  }

  async getSignedUrl(key: string, expiresIn: number = 3600): Promise<string> {
    const params: AWS.S3.GetObjectRequest = {
      Bucket: this.bucket,
      Key: key,
    };
    
    return this.s3.getSignedUrlPromise('getObject', {
      ...params,
      Expires: expiresIn,
    });
  }

  private extractKeyFromUrl(url: string): string | null {
    try {
      const urlObj = new URL(url);
      let pathname = urlObj.pathname;
      
      if (pathname.startsWith('/')) {
        pathname = pathname.substring(1);
      }
      
      // Remove bucket name if present in path
      if (pathname.startsWith(`${this.bucket}/`)) {
        pathname = pathname.substring(this.bucket.length + 1);
      }
      
      return pathname;
    } catch {
      return null;
    }
  }
}