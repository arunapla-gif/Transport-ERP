import React from 'react';
import { createRoot } from 'react-dom/client';
import html2canvas from 'html2canvas-pro';
const App = () => {
  return <div>Test</div>;
};
const root = createRoot(document.getElementById('root'));
root.render(<App />);
