import 'reflect-metadata';
import { Logger } from '@nestjs/common';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';
import { configureApp } from './bootstrap';

async function main() {
  const app = await NestFactory.create(AppModule);
  const env = configureApp(app);
  await app.listen(env.port, '0.0.0.0');
  Logger.log(`Lumi API on http://0.0.0.0:${env.port} (docs: /docs, env: ${env.nodeEnv})`, 'Bootstrap');
}
void main();
