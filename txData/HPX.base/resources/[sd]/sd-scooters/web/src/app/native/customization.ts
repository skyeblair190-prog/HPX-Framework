import catalog from './extrasCatalog.json';
export interface Customization {
    rear: string; trim: string; lighting: string; box: string;
}
export interface ExtraOption { id: string; label: string; fee: number; hex?: string; description?: string }
export interface ExtrasCatalog {
    defaults: Customization; rear: ExtraOption[]; trim: ExtraOption[];
    lighting: ExtraOption[]; box: ExtraOption[];
    presets: {id: string; label: string; description: string; options: Partial<Customization>}[];
}
export const EXTRAS: ExtrasCatalog = catalog;
export function extraFee(value: Customization, c = EXTRAS): number {
    let fee = 0;
    for (const key of ['rear', 'trim', 'lighting', 'box'] as const) fee += c[key]?.find(item => item.id === value[key])?.fee ?? 0;
    return fee;
}
export function attachmentKeys(value: Customization): Set<string> {
    const keys = new Set<string>();
    if (value.rear !== 'none') keys.add('rack');
    if (value.rear === 'delivery') keys.add(value.box && value.box !== 'stock' ? `delivery_${value.box}` : 'delivery');
    if (value.trim !== 'stock') for (const part of ['grip', 'deck', 'front', 'rear']) keys.add(`trim_${value.trim}_${part}`);
    if (value.lighting !== 'off') keys.add('light_' + value.lighting);
    return keys;
}
