import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { RoomEnvironment } from 'three/addons/environments/RoomEnvironment.js';
import modelUrl from './assets/scooter.glb';
import { loadExtras } from './previewExtras';
import type { Customization } from './customization';

const VIEW = new THREE.Vector3(2.35, 1.0, 2.75).normalize();
const FILL = 0.82;
const ZOOM_IN = 0.5;
const ZOOM_OUT = 1.9;
const FIRST_BUILD_DELAY = 450;
const MAX_REBUILDS = 3;
const MAX_BLANK_FRAMES = 2;

interface Stage {
    extras: Awaited<ReturnType<typeof loadExtras>>;
    renderer: THREE.WebGLRenderer;
    scene:    THREE.Scene;
    camera:   THREE.PerspectiveCamera;
    controls: OrbitControls;
    paint:    THREE.MeshStandardMaterial[];
    bounds:   { center: THREE.Vector3; radius: number; box: THREE.Box3 };
    lost:     boolean;
    framed?:  number;
}

interface Session {
    host:    HTMLElement;
    onError: () => void;
    colour:  string;
    extras:  Customization | null;
}

let stagePromise: Promise<Stage> | null = null;
let stage: Stage | null = null;
let raf = 0;
let rebuilds = 0;
let verifyLeft = 0;
const owners: Session[] = [];

async function modelBuffer(): Promise<ArrayBuffer> {
    if (!modelUrl.startsWith('data:')) {
        const res = await fetch(modelUrl);
        if (!res.ok) throw new Error('Model unavailable');
        return res.arrayBuffer();
    }
    const bin = atob(modelUrl.slice(modelUrl.indexOf(',') + 1));
    const bytes = new Uint8Array(bin.length);
    for (let i = 0; i < bin.length; i++) bytes[i] = bin.charCodeAt(i);
    return bytes.buffer;
}

function owner(): Session | null {
    for (let i = owners.length - 1; i >= 0; i--) if (owners[i].host.isConnected) return owners[i];
    return null;
}

function drewSomething(s: Stage): boolean {
    const gl = s.renderer.getContext();
    const w = gl.drawingBufferWidth, h = gl.drawingBufferHeight;
    if (!w || !h) return true;
    const pixels = new Uint8Array(w * h * 4);
    gl.readPixels(0, 0, w, h, gl.RGBA, gl.UNSIGNED_BYTE, pixels);
    for (let i = 3; i < pixels.length; i += 4) if (pixels[i] > 0) return true;
    return false;
}

function draw(): void {
    const s = stage;
    if (!s || raf || !owner()) return;
    raf = requestAnimationFrame(() => {
        raf = 0;
        if (stage !== s || !owner()) return;
        if (s.lost || s.renderer.getContext().isContextLost()) { recover(); return; }
        s.renderer.render(s.scene, s.camera);
        if (!verifyLeft) return;
        if (drewSomething(s)) { verifyLeft = 0; rebuilds = 0; return; }
        verifyLeft -= 1;
        if (verifyLeft > 0) { fit(); return; }
        console.warn('[scoot] 3D preview drew nothing after re-framing; rebuilding it');
        recover();
    });
}

function frame(keepView = false): void {
    const s = stage;
    if (!s) return;
    const fovY = THREE.MathUtils.degToRad(s.camera.fov) / 2;
    const fovX = Math.atan(Math.tan(fovY) * s.camera.aspect);
    const right = new THREE.Vector3().crossVectors(new THREE.Vector3(0,1,0),VIEW).normalize();
    const up = new THREE.Vector3().crossVectors(VIEW,right).normalize();
    let distance = 0;
    for(const x of [s.bounds.box.min.x,s.bounds.box.max.x]) for(const y of [s.bounds.box.min.y,s.bounds.box.max.y]) for(const z of [s.bounds.box.min.z,s.bounds.box.max.z]) {
        const p = new THREE.Vector3(x,y,z).sub(s.bounds.center);
        distance = Math.max(distance, p.dot(VIEW) + Math.max(Math.abs(p.dot(right))/Math.tan(fovX),Math.abs(p.dot(up))/Math.tan(fovY))/FILL);
    }
    s.controls.minDistance = distance * ZOOM_IN;
    s.controls.maxDistance = distance * ZOOM_OUT;
    const offset = s.camera.position.clone().sub(s.controls.target);
    const keep = keepView && s.framed && offset.lengthSq() > 0;
    s.controls.target.copy(s.bounds.center);
    if (keep) { const ratio = offset.length() / s.framed!; s.camera.position.copy(s.bounds.center).addScaledVector(offset.normalize(), distance * ratio); }
    else s.camera.position.copy(s.bounds.center).addScaledVector(VIEW, distance);
    s.framed = distance;
    s.controls.update();
    draw();
}

function zoom(factor: number): void {
    const s = stage;
    if (!s) return;
    const offset = s.camera.position.clone().sub(s.controls.target);
    const length = Math.min(s.controls.maxDistance, Math.max(s.controls.minDistance, offset.length() * factor));
    s.camera.position.copy(s.controls.target).addScaledVector(offset.normalize(), length);
    s.controls.update();
    draw();
}

function fit(): void {
    const s = stage, current = owner();
    if (!s || !current) return;
    const width = current.host.offsetWidth, height = current.host.offsetHeight;
    if (!width || !height) return;
    const size = s.renderer.getSize(new THREE.Vector2());
    const resized = size.x !== width || size.y !== height;
    s.camera.aspect = width / height;
    s.camera.updateProjectionMatrix();
    if (resized) s.renderer.setSize(width, height);
    frame(true);
    if (resized && !s.lost && !s.renderer.getContext().isContextLost()) s.renderer.render(s.scene, s.camera);
}

function keepStill(host: HTMLElement, s: Stage): void {
    try {
        if (s.lost || s.renderer.getContext().isContextLost()) return;
        s.renderer.render(s.scene, s.camera);
        host.style.backgroundImage = `url(${s.renderer.domElement.toDataURL('image/png')})`;
        host.style.backgroundSize = 'contain';
        host.style.backgroundPosition = 'center';
        host.style.backgroundRepeat = 'no-repeat';
    } catch { host.style.backgroundImage = ''; }
}

function attach(): void {
    const s = stage, current = owner();
    if (!s) return;
    if (!current) { s.renderer.domElement.remove(); return; }
    const previous = s.renderer.domElement.parentElement;
    if (previous !== current.host) {
        if (previous instanceof HTMLElement && previous.isConnected) keepStill(previous, s);
        current.host.appendChild(s.renderer.domElement);
    }
    s.paint.forEach(m => m.color.set(current.colour));
    if (current.extras) s.extras.update(current.extras);
    verifyLeft = MAX_BLANK_FRAMES;
    void current.host.offsetHeight;
    fit();
    draw();
    requestAnimationFrame(() => requestAnimationFrame(() => { if (owner() === current) current.host.style.backgroundImage = ''; }));
    window.setTimeout(() => { if (owner() === current) fit(); }, 50);
}

function disposeStage(s: Stage): void {
    const textures = new Set<THREE.Texture>();
    s.scene.traverse(ob => {
        if (!(ob instanceof THREE.Mesh)) return;
        ob.geometry.dispose();
        const materials = Array.isArray(ob.material) ? ob.material : [ob.material];
        materials.forEach(m => { Object.values(m).forEach(v => { if (v instanceof THREE.Texture) textures.add(v); }); m.dispose(); });
    });
    textures.forEach(t => t.dispose());
    s.scene.environment?.dispose();
    s.controls.dispose();
    s.renderer.domElement.remove();
    s.renderer.dispose();
}

function dropStage(): void {
    const s = stage;
    stage = null;
    stagePromise = null;
    cancelAnimationFrame(raf);
    raf = 0;
    verifyLeft = 0;
    if (s) disposeStage(s);
}

function recover(): void {
    const current = owner();
    dropStage();
    if (!current) return;
    if (rebuilds >= MAX_REBUILDS) {
        console.warn('[scoot] 3D preview could not recover its WebGL context; showing the poster');
        owners.forEach(o => o.onError());
        return;
    }
    rebuilds += 1;
    stageReady(current.host).then(() => attach(), () => owners.forEach(o => o.onError()));
}

async function buildStage(firstHost: HTMLElement, delay: number): Promise<Stage> {
    await new Promise(r => setTimeout(r, delay));
    const data = await modelBuffer();
    const canvas = document.createElement('canvas');
    if (firstHost.isConnected) firstHost.appendChild(canvas);
    const renderer = new THREE.WebGLRenderer({ canvas, alpha: true, antialias: true, powerPreference: 'low-power', preserveDrawingBuffer: true });
    renderer.setPixelRatio(Math.min(window.devicePixelRatio, 1.5));
    renderer.toneMapping = THREE.ACESFilmicToneMapping;
    renderer.toneMappingExposure = 1.15;
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(34, 1, .05, 30);
    const controls = new OrbitControls(camera, renderer.domElement);
    controls.enablePan = false; controls.enableZoom = true; controls.enableDamping = false;
    controls.zoomSpeed = 0.8;
    controls.minPolarAngle = .35; controls.maxPolarAngle = Math.PI * .64;
    controls.rotateSpeed = .65;
    controls.addEventListener('change', draw);
    const pmrem = new THREE.PMREMGenerator(renderer);
    const room = new RoomEnvironment();
    scene.environment = pmrem.fromScene(room, .04).texture;
    room.dispose(); pmrem.dispose();
    scene.add(new THREE.HemisphereLight(0xffffff, 0x7a8890, 2));
    const key = new THREE.DirectionalLight(0xfff4e9, 3); key.position.set(3, 4, 3); scene.add(key);
    const gltf = await new GLTFLoader().parseAsync(data, '');
    const paint: THREE.MeshStandardMaterial[] = [];
    gltf.scene.traverse(ob => {
        if (!(ob instanceof THREE.Mesh)) return;
        const mats = Array.isArray(ob.material) ? ob.material : [ob.material];
        mats.forEach(m => { if (m instanceof THREE.MeshStandardMaterial && m.name === 'ScootPaint') paint.push(m); });
    });
    scene.add(gltf.scene);
    const extras = await loadExtras(scene);
    const box = new THREE.Box3().setFromObject(gltf.scene).union(extras.box);
    const sphere = box.getBoundingSphere(new THREE.Sphere());
    const built: Stage = { renderer, scene, camera, controls, paint, extras, bounds: { center: sphere.center, radius: Math.max(sphere.radius, .01), box }, lost: false };
    renderer.domElement.addEventListener('webglcontextlost', event => {
        event.preventDefault();
        built.lost = true;
        if (stage === built) draw();
    });
    if (renderer.getContext().isContextLost()) {
        disposeStage(built);
        throw new Error('WebGL context lost while the preview was being built');
    }
    return built;
}

function stageReady(firstHost: HTMLElement): Promise<Stage> {
    if (!stagePromise) {
        const attempt = async (): Promise<Stage> => {
            let lastError: unknown;
            for (let i = 0; i <= MAX_REBUILDS; i++) {
                try { return await buildStage(firstHost, i === 0 ? FIRST_BUILD_DELAY : 250); }
                catch (error) { lastError = error; console.warn('[scoot] 3D preview build failed, retrying', error); }
            }
            throw lastError;
        };
        const pending: Promise<Stage> = attempt().then(
            s => {
                if (stagePromise !== pending) { disposeStage(s); return stageReady(firstHost); }
                stage = s;
                return s;
            },
            error => { if (stagePromise === pending) stagePromise = null; throw error; },
        );
        stagePromise = pending;
    }
    return stagePromise;
}

export async function createPreview(host: HTMLElement, initialColour: string, onReady: () => void, onError: () => void) {
    const session: Session = { host, onError, colour: initialColour, extras: null };
    let alive = true;
    try { await stageReady(host); }
    catch { if (alive) onError(); return { extras(_value: Customization) {}, colour() {}, rotate() {}, reset() {}, zoom() {}, refresh() {}, dispose() { alive = false; } }; }

    owners.push(session);
    attach();
    const ro = new ResizeObserver(() => { if (owner() === session) fit(); });
    ro.observe(host);
    const io = new IntersectionObserver(entries => { if (entries[0]?.isIntersecting && owner() === session) draw(); });
    io.observe(host);
    const onVisibility = () => { if (!document.hidden && owner() === session) attach(); };
    document.addEventListener('visibilitychange', onVisibility);
    onReady();

    return {
        extras(value: Customization) {
            session.extras = value;
            if (owner() === session) { stage?.extras.update(value); draw(); }
        },
        colour(value: string) {
            session.colour = value;
            if (owner() === session) { stage?.paint.forEach(m => m.color.set(value)); draw(); }
        },
        rotate(radians: number) {
            const st = stage; if (!st) return;
            const offset = st.camera.position.clone().sub(st.controls.target);
            offset.applyAxisAngle(new THREE.Vector3(0, 1, 0), radians);
            st.camera.position.copy(st.controls.target).add(offset);
            st.controls.update(); draw();
        },
        reset: () => frame(),
        zoom,
        refresh() {
            if (owner() !== session) return;
            if (!stage) { if (!stagePromise) recover(); return; }
            if (stage.lost || stage.renderer.getContext().isContextLost()) { recover(); return; }
            attach();
        },
        dispose() {
            if (!alive) return;
            alive = false;
            ro.disconnect(); io.disconnect();
            document.removeEventListener('visibilitychange', onVisibility);
            const index = owners.indexOf(session);
            if (index >= 0) owners.splice(index, 1);
            attach();
        },
    };
}
