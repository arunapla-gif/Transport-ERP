import React from 'react';
import './VanillaDemo.css';

export default function VanillaDemo() {
  return (
    <div className="vanilla-demo-container">
      <div className="vanilla-card">
        <div className="vanilla-header">
          <div className="vanilla-header-glow"></div>
          <h2 className="vanilla-subtitle">Vanilla CSS</h2>
          <div className="vanilla-title">Premium Card</div>
        </div>
        
        <div className="vanilla-body">
          <p className="vanilla-text">
            This entire component is built exclusively using a separate, custom Vanilla CSS file (<code>VanillaDemo.css</code>). It demonstrates how you can perfectly isolate and manage standard CSS in your React app.
          </p>
          
          <div className="vanilla-stats">
            <div className="vanilla-stat-row">
              <span className="vanilla-stat-label">Monthly Target</span>
              <span className="vanilla-stat-value">85%</span>
            </div>
            <div className="vanilla-stat-row">
              <span className="vanilla-stat-label">Active Shipments</span>
              <span className="vanilla-stat-value">1,204</span>
            </div>
          </div>
          
          <button className="vanilla-btn">
            Confirm Action
          </button>
        </div>
      </div>
    </div>
  );
}
