import { INestApplication, ValidationPipe } from '@nestjs/common';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { loadEnv } from './config/env';

/** Shared HTTP setup for main.ts and e2e tests. */
export function configureApp(app: INestApplication, { swagger = true } = {}) {
  const env = loadEnv();
  app.use(helmet({ contentSecurityPolicy: false }));
  app.enableCors({ origin: env.corsOrigins === '*' ? true : env.corsOrigins, credentials: true });
  app.useGlobalPipes(new ValidationPipe({ whitelist: true, forbidNonWhitelisted: true, transform: true }));
  app.enableShutdownHooks();
  if (swagger) {
    const doc = new DocumentBuilder()
      .setTitle('Lumi API')
      .setDescription('Auth, profiles, Soul/Voice Match, friends, realtime chat, feed. Realtime events: see README.')
      .setVersion('1.0')
      .addBearerAuth()
      .build();
    SwaggerModule.setup('docs', app, SwaggerModule.createDocument(app, doc));
  }
  return env;
}
