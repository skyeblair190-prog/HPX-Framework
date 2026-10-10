import type { MapStyleId } from '@/types';

export interface TileSource {
  base: string;
  ext: 'jpg' | 'png';
  maxZoom: number;
  px: number;
}

const CDN = 'https://sd-maptiles.pages.dev';

export const TILE_SOURCES: Record<MapStyleId, TileSource> = {
  satellite: { base: CDN, ext: 'jpg', maxZoom: 6, px: 1024 },
  atlas: { base: CDN, ext: 'jpg', maxZoom: 5, px: 1024 },
};

export interface MapStyle {
  id: MapStyleId;
  label: string;
  tiles: MapStyleId;
  filter: string;
  bg: string;
}

export const MAP_STYLES: MapStyle[] = [
  { id: 'satellite', label: 'Satellite', tiles: 'satellite', filter: 'none', bg: '#0c1219' },
  { id: 'atlas', label: 'Atlas', tiles: 'atlas', filter: 'none', bg: '#acc6e0' },
];

const TILE_V = 5;

export const tileUrl = (tiles: MapStyleId, z: number, x: number, y: number): string => {
  const s = TILE_SOURCES[tiles];
  return `${s.base}/${tiles}/${z}/${x}/${y}.${s.ext}?v=${TILE_V}`;
};

export const styleMaxZoom = (tiles: MapStyleId): number => TILE_SOURCES[tiles].maxZoom;

export const WORLD = { xMin: -5355, xMax: 6167, yMin: -3833, yMax: 7688 };

export const projectPct = (x: number, y: number) => ({
  left: ((x - WORLD.xMin) / (WORLD.xMax - WORLD.xMin)) * 100,
  top: ((WORLD.yMax - y) / (WORLD.yMax - WORLD.yMin)) * 100,
});

const STYLE_KEY = 'sd_scoot:adminMapStyle';

export const loadStyleId = (fallback: MapStyleId): MapStyleId => {
  try {
    const raw = window.localStorage.getItem(STYLE_KEY);
    if (raw && MAP_STYLES.some(s => s.id === raw)) return raw as MapStyleId;
  } catch {
  }
  return fallback;
};

export const saveStyleId = (id: MapStyleId): void => {
  try {
    window.localStorage.setItem(STYLE_KEY, id);
  } catch {
  }
};
