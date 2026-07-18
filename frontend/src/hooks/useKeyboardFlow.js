import { useEffect } from 'react';

export function useKeyboardFlow(options = {}) {
  const { onSave = null } = options;

  useEffect(() => {
    const handleKeyDown = (e) => {
      // 1. Handle Ctrl+S / Cmd+S for Save
      if ((e.ctrlKey || e.metaKey) && e.key === 's') {
        if (onSave) {
          e.preventDefault();
          onSave(e);
        }
        return;
      }

      // 2. Handle Enter to Next Field
      if (e.key === 'Enter') {
        const target = e.target;
        
        if (target.tagName === 'BUTTON' || target.tagName === 'TEXTAREA') {
          return;
        }

        e.preventDefault();

        const focusableSelector = 'input:not([disabled]):not([type="hidden"]):not([tabindex="-1"]), select:not([disabled]):not([tabindex="-1"]), button:not([disabled]):not([tabindex="-1"]), textarea:not([disabled]):not([tabindex="-1"]), [tabindex]:not([tabindex="-1"])';

        const focusableElements = Array.from(document.querySelectorAll(focusableSelector));
        const currentIndex = focusableElements.indexOf(target);
        
        if (currentIndex > -1) {
          for (let i = currentIndex + 1; i < focusableElements.length; i++) {
            const el = focusableElements[i];
            // Fast visibility check (offsetParent is null if display:none)
            if (el.offsetParent !== null) {
              el.focus();
              break;
            }
          }
        }
      }
    };

    document.addEventListener('keydown', handleKeyDown);
    return () => {
      document.removeEventListener('keydown', handleKeyDown);
    };
  }, [onSave]);
}
