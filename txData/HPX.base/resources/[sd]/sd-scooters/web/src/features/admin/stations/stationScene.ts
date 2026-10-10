import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import modelUrl from './assets/station.glb';


export interface StationLayout {
  slotX: number[];
  railStart: number;
  dockPitch: number;
}

export const DEFAULT_LAYOUT: StationLayout = { slotX: [-1.05, -0.35, 0.35, 1.05], railStart: -1.4, dockPitch: 0.7 };

const VIEW = new THREE.Vector3(0.75, 0.62, 2.1).normalize();
const FILL = 0.9;

let parts: Promise<Record<string, THREE.Object3D>> | null = null;

function loadParts(): Promise<Record<string, THREE.Object3D>> {
  parts ??= new GLTFLoader().loadAsync(modelUrl).then(gltf => {
    const found: Record<string, THREE.Object3D> = {};
    for (const child of gltf.scene.children) found[child.name] = child;
    return found;
  }).catch(error => {
    parts = null;
    throw error;
  });
  return parts;
}

interface Stage {
  source: Record<string, THREE.Object3D>;
  renderer: THREE.WebGLRenderer;
  scene: THREE.Scene;
  camera: THREE.PerspectiveCamera;
  controls: OrbitControls;
  paint: THREE.MeshStandardMaterial[];
  station: THREE.Group;
}

let stagePromise: Promise<Stage> | null = null;
let owner: object | null = null;
let raf = 0;

function dropStage(stage: Stage): void {
  stagePromise = null;
  owner = null;
  cancelAnimationFrame(raf);
  raf = 0;
  stage.controls.dispose();
  stage.scene.environment?.dispose();
  stage.renderer.domElement.remove();
  stage.renderer.dispose();
}

async function buildStage(): Promise<Stage> {
  const source = await loadParts();

  const renderer = new THREE.WebGLRenderer({ alpha: true, antialias: true, powerPreference: 'low-power' });
  renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
  renderer.toneMapping = THREE.ACESFilmicToneMapping;
  renderer.toneMappingExposure = 0.95;

  const scene = new THREE.Scene();
  const camera = new THREE.PerspectiveCamera(30, 1, 0.05, 60);
  const controls = new OrbitControls(camera, renderer.domElement);
  controls.enablePan = false;
  controls.enableDamping = false;
  controls.zoomSpeed = 0.8;
  controls.rotateSpeed = 0.6;
  controls.minPolarAngle = 0.3;
  controls.maxPolarAngle = Math.PI * 0.55;

  const pmrem = new THREE.PMREMGenerator(renderer);
  const room = new RoomEnvironment();
  scene.environment = pmrem.fromScene(room, 0.04).texture;
  room.dispose();
  pmrem.dispose();
  scene.add(new THREE.HemisphereLight(0xffffff, 0x7a8890, 1.6));
  const key = new THREE.DirectionalLight(0xfff4e9, 2.6);
  key.position.set(3, 5, 4);
  scene.add(key);

  const paint: THREE.MeshStandardMaterial[] = [];
  Object.values(source).forEach(root =>
    root.traverse(ob => {
      if (!(ob instanceof THREE.Mesh)) return;
      const mats = Array.isArray(ob.material) ? ob.material : [ob.material];
      mats.forEach(m => m instanceof THREE.MeshStandardMaterial && m.name === 'StationPaint' && !paint.includes(m) && paint.push(m));
    }),
  );

  const station = new THREE.Group();
  scene.add(station);

  const stage: Stage = { source, renderer, scene, camera, controls, paint, station };
  renderer.domElement.addEventListener('webglcontextlost', event => {
    event.preventDefault();
    dropStage(stage);
  });
  return stage;
}

function stageReady(): Promise<Stage> {
  stagePromise ??= buildStage().catch(error => {
    stagePromise = null;
    throw error;
  });
  return stagePromise;
}

export interface StationPreview {
  build: (count: number) => void;
  colour: (hex: string) => void;
  dispose: () => void;
}

export async function createStationPreview(host: HTMLElement, count: number, hex: string, layout: StationLayout): Promise<StationPreview> {
  const stage = await stageReady();
  const { source, renderer, scene, camera, controls, paint, station } = stage;
  const token = {};
  owner = token;
  let framed = false;
  let alive = true;

  const draw = () => {
    if (raf || owner !== token) return;
    raf = requestAnimationFrame(() => {
      raf = 0;
      if (owner === token) renderer.render(scene, camera);
    });
  };
  controls.addEventListener('change', draw);

  const place = (name: string, x: number) => {
    const part = source[name];
    if (!part) return;
    const copy = part.clone();
    copy.position.set(x, 0, 0);
    station.add(copy);
  };

  const frame = () => {
    const box = new THREE.Box3().setFromObject(station);
    if (box.isEmpty()) return;
    const centre = box.getCenter(new THREE.Vector3());
    const dir = framed ? camera.position.clone().sub(controls.target).normalize() : VIEW.clone();
    const fovY = THREE.MathUtils.degToRad(camera.fov) / 2;
    const fovX = Math.atan(Math.tan(fovY) * camera.aspect);
    const right = new THREE.Vector3().crossVectors(new THREE.Vector3(0, 1, 0), dir).normalize();
    const up = new THREE.Vector3().crossVectors(dir, right).normalize();
    let distance = 0;
    for (const x of [box.min.x, box.max.x])
      for (const y of [box.min.y, box.max.y])
        for (const z of [box.min.z, box.max.z]) {
          const p = new THREE.Vector3(x, y, z).sub(centre);
          distance = Math.max(distance, p.dot(dir) + Math.max(Math.abs(p.dot(right)) / Math.tan(fovX), Math.abs(p.dot(up)) / Math.tan(fovY)) / FILL);
        }
    controls.minDistance = distance * 0.45;
    controls.maxDistance = distance * 2.2;
    controls.target.copy(centre);
    camera.position.copy(centre).addScaledVector(dir, distance);
    controls.update();
    framed = true;
    draw();
  };

  const build = (n: number) => {
    if (owner !== token) return;
    station.clear();
    const docks = Math.max(1, Math.min(layout.slotX.length, n));
    place('totem', 0);
    place('tshell', 0);
    for (let slot = 1; slot <= docks; slot++) {
      place(`dock_${slot}`, layout.slotX[slot - 1]);
      place('shell', layout.slotX[slot - 1]);
    }
    place('end', layout.railStart + layout.dockPitch * docks);
    frame();
  };

  const fit = () => {
    if (owner !== token) return;
    const width = host.clientWidth;
    const height = host.clientHeight;
    if (!width || !height) return;
    camera.aspect = width / height;
    camera.updateProjectionMatrix();
    renderer.setSize(width, height, false);
    frame();
  };
  const resize = new ResizeObserver(fit);
  resize.observe(host);

  host.appendChild(renderer.domElement);
  paint.forEach(m => m.color.set(hex));
  build(count);
  fit();

  return {
    build,
    colour(value) {
      if (owner !== token) return;
      paint.forEach(m => m.color.set(value));
      draw();
    },
    dispose() {
      if (!alive) return;
      alive = false;
      resize.disconnect();
      controls.removeEventListener('change', draw);
      if (owner !== token) return;
      owner = null;
      cancelAnimationFrame(raf);
      raf = 0;
      renderer.domElement.remove();
    },
  };
}
