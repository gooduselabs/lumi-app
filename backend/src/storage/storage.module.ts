import { Global, Module } from '@nestjs/common';
import { APP_ENV, AppEnv } from '../config/env';
import { LocalDiskDriver } from './local.driver';
import { S3Driver } from './s3.driver';
import { STORAGE, StorageDriver } from './storage.driver';

export function createStorage(env: AppEnv): StorageDriver {
  return env.storage.driver === 's3' ? new S3Driver(env.storage.s3) : new LocalDiskDriver(env.storage.localDir);
}

@Global()
@Module({
  providers: [{ provide: STORAGE, inject: [APP_ENV], useFactory: createStorage }],
  exports: [STORAGE],
})
export class StorageModule {}
