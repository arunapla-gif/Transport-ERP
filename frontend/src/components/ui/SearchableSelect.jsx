import React, { useState, useEffect, useRef } from 'react';
import { Search, ChevronDown, X } from 'lucide-react';

export function SearchableSelect({ label, options, value, onChange, placeholder = "Search...", autoFocus = false, className = "", id, nextFocusId }) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [highlightedIndex, setHighlightedIndex] = useState(-1);
  const wrapperRef = useRef(null);
  const listboxRef = useRef(null);
  const optionRefs = useRef([]);
  const inputRef = useRef(null);

  const selectedOption = options.find(opt => opt.value === value);

  const filteredOptions = options.filter(opt => 
    opt.label.toLowerCase().includes(searchTerm.toLowerCase())
  );

  useEffect(() => {
    function handleClickOutside(event) {
      if (wrapperRef.current && !wrapperRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

  // Guarantee focus is captured when opening
  useEffect(() => {
    if (isOpen && inputRef.current) {
      inputRef.current.focus();
    }
  }, [isOpen]);

  useEffect(() => {
    if (autoFocus && wrapperRef.current) {
      setTimeout(() => {
        if (inputRef.current) inputRef.current.focus();
      }, 50);
    }
  }, [autoFocus]);

  useEffect(() => {
    setHighlightedIndex(filteredOptions.length > 0 ? 0 : -1);
  }, [searchTerm, options]);

  useEffect(() => {
    if (isOpen && highlightedIndex >= 0 && optionRefs.current[highlightedIndex]) {
      optionRefs.current[highlightedIndex].scrollIntoView({
        block: 'nearest',
      });
    }
  }, [highlightedIndex, isOpen]);

  const advanceFocus = () => {
    if (nextFocusId) {
      setTimeout(() => {
        const nextEl = document.getElementById(nextFocusId);
        if (nextEl) nextEl.focus();
      }, 100);
    }
  };

  const handleSelect = (optionValue) => {
    onChange(optionValue);
    setSearchTerm('');
    setIsOpen(false);
    advanceFocus(); // Trigger advance after mouse click too!
  };

  const handleClear = (e) => {
    e.stopPropagation();
    onChange('');
    setSearchTerm('');
    setIsOpen(true);
  };

  const handleKeyDown = (e) => {
    if (!isOpen) {
      if (e.key === 'ArrowDown' || e.key === 'ArrowUp') {
        e.preventDefault();
        setIsOpen(true);
      } else if (e.key === 'Enter') {
        e.preventDefault();
        if (value) {
          advanceFocus(); // Advance if already filled!
        } else {
          setIsOpen(true);
        }
      }
      return;
    }

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setHighlightedIndex(prev => prev < filteredOptions.length - 1 ? prev + 1 : prev);
        break;
      case 'ArrowUp':
        e.preventDefault();
        setHighlightedIndex(prev => (prev > 0 ? prev - 1 : 0));
        break;
      case 'Enter':
        if (highlightedIndex >= 0 && highlightedIndex < filteredOptions.length) {
          e.preventDefault();
          handleSelect(filteredOptions[highlightedIndex].value);
          // auto-advance is handled in handleSelect
        }
        break;
      case 'Escape':
        e.preventDefault();
        setIsOpen(false);
        break;
      default:
        break;
    }
  };

  return (
    <div className={`flex flex-col relative ${className}`} ref={wrapperRef} onKeyDown={handleKeyDown}>
      {label && <label className="text-xs font-bold tracking-wider text-slate-500 uppercase mb-1">{label}</label>}
      
      <div 
        className={`relative flex items-center w-full px-3 py-2 rounded-lg text-sm transition-all cursor-text
          ${isOpen ? 'bg-white border-blue-500 ring-2 ring-blue-500/20' : 'bg-slate-50 border-slate-200 border hover:border-slate-300'}`}
        onClick={() => setIsOpen(true)}
      >
        {(!isOpen && selectedOption) ? (
           <div id={id} className="flex-1 truncate text-slate-800 font-medium" tabIndex={0} onFocus={() => setIsOpen(true)}>
             {selectedOption.label}
           </div>
        ) : (
          <input
            id={id}
            ref={inputRef}
            type="text"
            className="w-full bg-transparent outline-none text-slate-800 font-medium placeholder:text-slate-400"
            placeholder={selectedOption ? selectedOption.label : placeholder}
            value={searchTerm}
            onChange={(e) => setSearchTerm(e.target.value)}
            onFocus={() => setIsOpen(true)}
          />
        )}

        <div className="flex items-center gap-1 text-slate-400 ml-2">
          {value && (
            <button type="button" onClick={handleClear} className="hover:text-rose-500 transition-colors p-1" tabIndex={-1}>
              <X size={14} />
            </button>
          )}
          <ChevronDown size={16} className={`transition-transform duration-200 ${isOpen ? 'rotate-180' : ''}`} />
        </div>
      </div>

      {isOpen && (
        <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-slate-200 rounded-lg shadow-xl z-50 max-h-60 overflow-y-auto" ref={listboxRef}>
          {filteredOptions.length > 0 ? (
            filteredOptions.map((opt, index) => (
              <div
                key={opt.value}
                ref={el => optionRefs.current[index] = el}
                className={`px-3 py-2 cursor-pointer text-sm transition-colors
                  ${index === highlightedIndex ? 'bg-indigo-50 text-indigo-700' : 'text-slate-700 hover:bg-slate-50'}
                  ${opt.value === value ? 'font-bold bg-indigo-50/50' : ''}
                `}
                onClick={() => handleSelect(opt.value)}
                onMouseEnter={() => setHighlightedIndex(index)}
              >
                {opt.label}
              </div>
            ))
          ) : (
            <div className="px-3 py-4 text-center text-sm text-slate-500">
              No results found
            </div>
          )}
        </div>
      )}
    </div>
  );
}
