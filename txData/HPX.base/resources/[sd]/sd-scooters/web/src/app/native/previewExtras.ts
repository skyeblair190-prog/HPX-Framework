import * as THREE from 'three';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import extrasUrl from './assets/extras.glb';
import { attachmentKeys, EXTRAS } from './customization';
import type { Customization } from './customization';

const TRIM_SOURCE = 'silver';
const TRIM_MATERIAL = 'EXTRA_trim_silver Web';
const BOX_MATERIAL = 'DELIVERY_teal Web';

export async function loadExtras(scene: THREE.Scene) {
    const gltf = await new GLTFLoader().loadAsync(extrasUrl);
    const root = gltf.scene;
    scene.add(root);
    const trimMaterials = new Set<THREE.MeshStandardMaterial>();
    const boxMaterials = new Set<THREE.MeshStandardMaterial>();
    let stockBand: THREE.Color | null = null;
    root.traverse(ob => {
        const mesh = ob as THREE.Mesh;
        if (!mesh.isMesh) return;
        for (const m of Array.isArray(mesh.material) ? mesh.material : [mesh.material]) {
            if (!(m instanceof THREE.MeshStandardMaterial)) continue;
            if (m.name === TRIM_MATERIAL) {
                m.map = null;
                m.needsUpdate = true;
                trimMaterials.add(m);
            }
            if (m.name === BOX_MATERIAL) {
                m.map = null;
                m.needsUpdate = true;
                stockBand = stockBand ?? m.color.clone();
                boxMaterials.add(m);
            }
        }
    });
    const glow = new THREE.PointLight(0x60dcff,.3,.7,2);glow.position.set(0,.11,0);scene.add(glow);
    const haloCanvas=document.createElement('canvas');haloCanvas.width=128;haloCanvas.height=128;
    const ctx=haloCanvas.getContext('2d')!;const gradient=ctx.createRadialGradient(64,64,0,64,64,64);gradient.addColorStop(0,'rgba(255,255,255,.7)');gradient.addColorStop(1,'rgba(255,255,255,0)');ctx.fillStyle=gradient;ctx.fillRect(0,0,128,128);
    const halo=new THREE.Mesh(new THREE.PlaneGeometry(.6,.9),new THREE.MeshBasicMaterial({map:new THREE.CanvasTexture(haloCanvas),transparent:true,depthWrite:false}));halo.rotation.x=-Math.PI/2;halo.position.y=.007;scene.add(halo);
    function update(value: Customization) {
        const keys=attachmentKeys(value);
        const trimHex=EXTRAS.trim.find(item=>item.id===value.trim)?.hex;
        if(trimHex){
            for(const key of [...keys]) if(key.startsWith(`trim_${value.trim}_`)){keys.delete(key);keys.add(key.replace(`trim_${value.trim}_`,`trim_${TRIM_SOURCE}_`));}
            for(const m of trimMaterials) m.color.set(trimHex);
        }
        const boxKey=`delivery_${value.box}`;
        if(keys.delete(boxKey))keys.add('delivery');
        const bandHex=EXTRAS.box?.find(item=>item.id===value.box)?.hex;
        for(const m of boxMaterials){if(bandHex)m.color.set(bandHex);else if(stockBand)m.color.copy(stockBand);}
        root.traverse(ob=>{if(ob.name.startsWith('SX_'))ob.visible=keys.has(ob.name.slice(3));});
        const colour=EXTRAS.lighting.find(item=>item.id===value.lighting)?.hex;
        halo.visible=glow.visible=!!colour;
        if(colour){glow.color.set(colour);halo.material.color.set(colour);}
    }
    update(EXTRAS.defaults);
    return {update,box:new THREE.Box3().setFromObject(root)};
}
