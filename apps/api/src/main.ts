import { NestFactory } from '@nestjs/core';
import { Logger, ValidationPipe } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { DocumentBuilder, SwaggerModule } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { ApiExceptionFilter } from './common/filters/api-exception.filter';

const ALLOWED_ORIGIN_PATTERNS: RegExp[] = [
  /^https:\/\/(.*\.)?smwhr\.dev$/,
  /^https:\/\/(.*\.)?smwhr\.quest$/,
  /^https:\/\/.*\.vercel\.app$/,
  /^https:\/\/.*\.ngrok-free\.app$/,
  /^https:\/\/.*\.ngrok\.app$/,
  /^http:\/\/localhost(:\d+)?$/,
  /^http:\/\/127\.0\.0\.1(:\d+)?$/,
];

async function bootstrap() {
  const app = await NestFactory.create(AppModule);
  const config = app.get(ConfigService);
  const logger = new Logger('Bootstrap');
  const httpLogger = new Logger('HTTP');

  // Diagnostic: one line per request → `<METHOD> <URL> <UA?> → <STATUS>
  // <BYTES> · <MS>ms`. Lives at the very top of the middleware chain
  // so it logs even for requests that fail validation or auth — the
  // mobile sometimes can't tell whether its request actually hit the
  // server, and this is the cheap answer.
  app.use(
    (
      req: { method: string; originalUrl: string; headers: Record<string, string | string[] | undefined> },
      res: { statusCode: number; on: (event: string, cb: () => void) => void; getHeader: (name: string) => string | number | string[] | undefined },
      next: () => void,
    ) => {
      const t0 = Date.now();
      res.on('finish', () => {
        const ms = Date.now() - t0;
        const len = res.getHeader('content-length') ?? '-';
        const ua = req.headers['user-agent'];
        const uaShort = typeof ua === 'string' ? ua.slice(0, 32) : '-';
        httpLogger.log(
          `${req.method} ${req.originalUrl} → ${res.statusCode} ${len}B · ${ms}ms · ua=${uaShort}`,
        );
      });
      next();
    },
  );

  app.use(
    helmet({
      contentSecurityPolicy: false, // Swagger UI needs inline scripts
      crossOriginEmbedderPolicy: false,
    }),
  );

  app.enableCors({
    origin: (origin: string | undefined, cb: (err: Error | null, allow?: boolean) => void) => {
      if (!origin) return cb(null, true); // mobile apps, curl, server-side
      if (ALLOWED_ORIGIN_PATTERNS.some((re) => re.test(origin))) {
        return cb(null, true);
      }
      return cb(null, false);
    },
    credentials: true,
    methods: ['GET', 'POST', 'PATCH', 'DELETE', 'OPTIONS'],
  });

  app.useGlobalPipes(
    new ValidationPipe({
      whitelist: true,
      transform: true,
      forbidNonWhitelisted: true,
      transformOptions: { enableImplicitConversion: true },
    }),
  );
  app.useGlobalFilters(new ApiExceptionFilter());

  const swaggerConfig = new DocumentBuilder()
    .setTitle('smwhr API')
    .setDescription('You were somewhere. — backend for R0.1.')
    .setVersion('0.1.0')
    .addBearerAuth()
    .build();
  const document = SwaggerModule.createDocument(app, swaggerConfig);
  SwaggerModule.setup('docs', app, document);

  const port = config.get<number>('port') ?? 3000;
  await app.listen(port, '0.0.0.0');
  logger.log(`smwhr api up on http://localhost:${port}`);
  logger.log(`Swagger docs at http://localhost:${port}/docs`);
}
bootstrap();
