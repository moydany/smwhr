-- AlterTable
ALTER TABLE "events" ADD COLUMN     "geofence_center" geography(Point, 4326),
ADD COLUMN     "geofence_polygon" geography(Polygon, 4326);

-- GiST indexes for fast ST_Contains lookups
CREATE INDEX "events_geofence_polygon_idx" ON "events" USING GIST ("geofence_polygon");
CREATE INDEX "events_geofence_center_idx" ON "events" USING GIST ("geofence_center");
