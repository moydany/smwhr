-- CreateTable
CREATE TABLE "users" (
    "id" UUID NOT NULL,
    "handle" VARCHAR(20) NOT NULL,
    "displayName" VARCHAR(40) NOT NULL,
    "email" TEXT NOT NULL,
    "avatarUrl" TEXT,
    "bio" VARCHAR(140),
    "city" TEXT,
    "countryCode" VARCHAR(2) NOT NULL DEFAULT 'MX',
    "interests" TEXT[],
    "authProvider" TEXT NOT NULL,
    "authProviderId" TEXT,
    "supabaseUserId" UUID,
    "timezone" TEXT NOT NULL DEFAULT 'America/Mexico_City',
    "language" VARCHAR(2) NOT NULL DEFAULT 'es',
    "pushToken" TEXT,
    "pushPlatform" TEXT,
    "notificationPromptShownAt" TIMESTAMP(3),
    "onboardingCompletedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "lastActiveAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "users_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "events" (
    "id" UUID NOT NULL,
    "slug" VARCHAR(100) NOT NULL,
    "title" TEXT NOT NULL,
    "artist" TEXT,
    "venueName" TEXT NOT NULL,
    "venueAddress" TEXT,
    "city" TEXT NOT NULL,
    "countryCode" VARCHAR(2) NOT NULL DEFAULT 'MX',
    "category" TEXT NOT NULL,
    "subcategory" TEXT,
    "startsAt" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "dwellMinimumMin" INTEGER NOT NULL DEFAULT 60,
    "geofenceRadiusM" INTEGER,
    "externalSource" TEXT,
    "externalId" TEXT,
    "externalUrl" TEXT,
    "heroImageUrl" TEXT,
    "heroColor" VARCHAR(7),
    "badgeTemplateId" UUID,
    "intentCount" INTEGER NOT NULL DEFAULT 0,
    "badgeCount" INTEGER NOT NULL DEFAULT 0,
    "totalCapacity" INTEGER,
    "status" TEXT NOT NULL DEFAULT 'scheduled',
    "isFeatured" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "intents" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "eventId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "intents_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "locus_events" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "eventId" UUID NOT NULL,
    "eventType" TEXT NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "accuracy" DOUBLE PRECISION,
    "altitude" DOUBLE PRECISION,
    "speed" DOUBLE PRECISION,
    "heading" DOUBLE PRECISION,
    "activity" TEXT,
    "confidence" DOUBLE PRECISION,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "isInsidePolygon" BOOLEAN NOT NULL DEFAULT false,
    "rawPayload" JSONB,

    CONSTRAINT "locus_events_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "geolocator_pings" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "eventId" UUID NOT NULL,
    "latitude" DOUBLE PRECISION NOT NULL,
    "longitude" DOUBLE PRECISION NOT NULL,
    "accuracy" DOUBLE PRECISION,
    "altitude" DOUBLE PRECISION,
    "timestamp" TIMESTAMP(3) NOT NULL,
    "receivedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "isInsidePolygon" BOOLEAN NOT NULL DEFAULT false,
    "batteryLevel" INTEGER,

    CONSTRAINT "geolocator_pings_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "checkins" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "eventId" UUID NOT NULL,
    "primarySource" TEXT NOT NULL,
    "reconciliationReason" TEXT,
    "agreementScore" DOUBLE PRECISION,
    "reconciledAt" TIMESTAMP(3),
    "dwellMinutes" INTEGER NOT NULL DEFAULT 0,
    "firstPointAt" TIMESTAMP(3),
    "lastPointAt" TIMESTAMP(3),
    "totalPointsCollected" INTEGER NOT NULL DEFAULT 0,
    "locusEventsCount" INTEGER NOT NULL DEFAULT 0,
    "geolocatorPingsCount" INTEGER NOT NULL DEFAULT 0,
    "integrityToken" TEXT,
    "integrityVerdict" TEXT,
    "integrityPlatform" TEXT,
    "integrityCheckedAt" TIMESTAMP(3),
    "deviceId" TEXT,
    "deviceModel" TEXT,
    "appVersion" TEXT,
    "photoId" UUID,
    "verificationScore" INTEGER NOT NULL DEFAULT 0,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "verificationReason" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "checkins_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "photos" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "storagePath" TEXT NOT NULL,
    "publicUrl" TEXT,
    "exifTimestamp" TIMESTAMP(3),
    "exifLatitude" DOUBLE PRECISION,
    "exifLongitude" DOUBLE PRECISION,
    "exifRaw" JSONB,
    "isExifValid" BOOLEAN NOT NULL DEFAULT false,
    "isInsideGeofence" BOOLEAN NOT NULL DEFAULT false,
    "isWithinTimeWindow" BOOLEAN NOT NULL DEFAULT false,
    "nsfwScore" DOUBLE PRECISION,
    "nsfwFlagged" BOOLEAN NOT NULL DEFAULT false,
    "processingStatus" TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "photos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "badge_templates" (
    "id" UUID NOT NULL,
    "name" TEXT NOT NULL,
    "category" TEXT NOT NULL,
    "variant" TEXT,
    "frameSvgUrl" TEXT NOT NULL,
    "accentColor" VARCHAR(7) NOT NULL,
    "ambientColor" VARCHAR(7),
    "textureUrl" TEXT,
    "config" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "badge_templates_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "badges" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "eventId" UUID NOT NULL,
    "templateId" UUID NOT NULL,
    "serialNumber" INTEGER NOT NULL,
    "totalForEvent" INTEGER NOT NULL,
    "composedImageUrl" TEXT,
    "shareImageUrl" TEXT,
    "verificationScore" INTEGER NOT NULL DEFAULT 0,
    "isVerified" BOOLEAN NOT NULL DEFAULT false,
    "awardedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "badges_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "waitlist_signups" (
    "id" UUID NOT NULL,
    "email" TEXT NOT NULL,
    "source" TEXT NOT NULL DEFAULT 'landing',
    "referrer" TEXT,
    "interests" TEXT[],
    "convertedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "waitlist_signups_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "system_events" (
    "id" UUID NOT NULL,
    "type" TEXT NOT NULL,
    "userId" UUID,
    "eventId" UUID,
    "metadata" JSONB,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "system_events_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "users_handle_key" ON "users"("handle");

-- CreateIndex
CREATE UNIQUE INDEX "users_email_key" ON "users"("email");

-- CreateIndex
CREATE UNIQUE INDEX "users_supabaseUserId_key" ON "users"("supabaseUserId");

-- CreateIndex
CREATE INDEX "users_email_idx" ON "users"("email");

-- CreateIndex
CREATE INDEX "users_handle_idx" ON "users"("handle");

-- CreateIndex
CREATE INDEX "users_city_idx" ON "users"("city");

-- CreateIndex
CREATE UNIQUE INDEX "events_slug_key" ON "events"("slug");

-- CreateIndex
CREATE INDEX "events_category_startsAt_idx" ON "events"("category", "startsAt");

-- CreateIndex
CREATE INDEX "events_city_startsAt_idx" ON "events"("city", "startsAt");

-- CreateIndex
CREATE INDEX "events_status_startsAt_idx" ON "events"("status", "startsAt");

-- CreateIndex
CREATE INDEX "events_isFeatured_startsAt_idx" ON "events"("isFeatured", "startsAt");

-- CreateIndex
CREATE INDEX "intents_eventId_idx" ON "intents"("eventId");

-- CreateIndex
CREATE UNIQUE INDEX "intents_userId_eventId_key" ON "intents"("userId", "eventId");

-- CreateIndex
CREATE INDEX "locus_events_userId_eventId_timestamp_idx" ON "locus_events"("userId", "eventId", "timestamp");

-- CreateIndex
CREATE INDEX "locus_events_eventId_eventType_idx" ON "locus_events"("eventId", "eventType");

-- CreateIndex
CREATE INDEX "geolocator_pings_userId_eventId_timestamp_idx" ON "geolocator_pings"("userId", "eventId", "timestamp");

-- CreateIndex
CREATE UNIQUE INDEX "checkins_photoId_key" ON "checkins"("photoId");

-- CreateIndex
CREATE INDEX "checkins_eventId_isVerified_idx" ON "checkins"("eventId", "isVerified");

-- CreateIndex
CREATE INDEX "checkins_primarySource_idx" ON "checkins"("primarySource");

-- CreateIndex
CREATE UNIQUE INDEX "checkins_userId_eventId_key" ON "checkins"("userId", "eventId");

-- CreateIndex
CREATE INDEX "photos_userId_idx" ON "photos"("userId");

-- CreateIndex
CREATE INDEX "badges_eventId_serialNumber_idx" ON "badges"("eventId", "serialNumber");

-- CreateIndex
CREATE INDEX "badges_userId_awardedAt_idx" ON "badges"("userId", "awardedAt");

-- CreateIndex
CREATE UNIQUE INDEX "badges_userId_eventId_key" ON "badges"("userId", "eventId");

-- CreateIndex
CREATE UNIQUE INDEX "waitlist_signups_email_key" ON "waitlist_signups"("email");

-- CreateIndex
CREATE INDEX "waitlist_signups_source_idx" ON "waitlist_signups"("source");

-- CreateIndex
CREATE INDEX "system_events_type_createdAt_idx" ON "system_events"("type", "createdAt");

-- CreateIndex
CREATE INDEX "system_events_userId_createdAt_idx" ON "system_events"("userId", "createdAt");

-- AddForeignKey
ALTER TABLE "events" ADD CONSTRAINT "events_badgeTemplateId_fkey" FOREIGN KEY ("badgeTemplateId") REFERENCES "badge_templates"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "intents" ADD CONSTRAINT "intents_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "intents" ADD CONSTRAINT "intents_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "locus_events" ADD CONSTRAINT "locus_events_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "locus_events" ADD CONSTRAINT "locus_events_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "geolocator_pings" ADD CONSTRAINT "geolocator_pings_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "geolocator_pings" ADD CONSTRAINT "geolocator_pings_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_photoId_fkey" FOREIGN KEY ("photoId") REFERENCES "photos"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "checkins" ADD CONSTRAINT "checkins_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "photos" ADD CONSTRAINT "photos_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "badges" ADD CONSTRAINT "badges_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "badges" ADD CONSTRAINT "badges_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "events"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "badges" ADD CONSTRAINT "badges_templateId_fkey" FOREIGN KEY ("templateId") REFERENCES "badge_templates"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
