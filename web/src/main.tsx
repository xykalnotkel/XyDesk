import { StrictMode } from 'react';
import { createRoot } from 'react-dom/client';
import App from './App';
import './style.css';

createRoot(document.getElementById('root')!).render(
  <StrictMode>
    <App />
  </StrictMode>,
);

document.addEventListener('contextmenu',e=>{if(e.target instanceof HTMLImageElement)e.preventDefault();});
document.addEventListener('dragstart',e=>{if(e.target instanceof HTMLImageElement)e.preventDefault();});
