import {useState} from 'react';
export function MappingPicker({label,options,values,onChange,multiple=false}:{label:string;options:(number|string)[][];values:(number|string)[];onChange:(values:(number|string)[])=>void;multiple?:boolean}){
 const [query,setQuery]=useState('');
 const filtered=options.filter(([,name])=>String(name).toLowerCase().includes(query.trim().toLowerCase()));
 return <fieldset className="mapping-picker"><legend>{label}</legend>
 {options.length>12&&<input type="search" aria-label={`Cari ${label.toLowerCase()}`} placeholder="Cari tombol, mis. F1 / Ctrl…" value={query} onChange={e=>setQuery(e.target.value)}/>}
 <div className="mapping-options" role="group" aria-label={label}>
 {filtered.map(([value,name])=>{const selected=values.includes(value);return <button type="button" key={value} aria-pressed={selected} disabled={multiple&&!selected&&values.length>=6} onClick={()=>onChange(multiple?(selected?values.filter(v=>v!==value):[...values,value]):[value])}>{String(name)}</button>;})}
 {!filtered.length&&<p>Tombol tidak ditemukan.</p>}</div>
 {multiple&&<small>{values.length}/6 tombol · modifier ditekan lebih dulu</small>}
 </fieldset>;
}
