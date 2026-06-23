import React, { useState, useEffect, useRef } from 'react';
import { ChevronDown, X, Loader2 } from 'lucide-react';

export const AsyncSearchableSelect = React.memo(function AsyncSearchableSelect({ 
  label, fetchOptions, value, initialOption, onChange, placeholder = "Search...", autoFocus = false, className = "", id, nextFocusId 
}) {
  const [isOpen, setIsOpen] = useState(false);
  const [searchTerm, setSearchTerm] = useState('');
  const [highlightedIndex, setHighlightedIndex] = useState(-1);
  const [options, setOptions] = useState([]);
  const [loading, setLoading] = useState(false);
  const [selectedOptionCache, setSelectedOptionCache] = useState(initialOption || null);

  const wrapperRef = useRef(null);
  const listboxRef = useRef(null);
  const optionRefs = useRef([]);
  const inputRef = useRef(null);
  const debounceRef = useRef(null);

  useEffect(() => {
    if (initialOption && initialOption.value === value) {
      setSelectedOptionCache(initialOption);
    }
  }, [initialOption, value]);

  useEffect(() => {
    if (!value) {
      setSelectedOptionCache(null);
    }
  }, [value]);

  const selectedOption = selectedOptionCache;

  useEffect(() => {
    if (!isOpen) return;

    if (debounceRef.current) clearTimeout(debounceRef.current);
    
    debounceRef.current = setTimeout(async () => {
      setLoading(true);
      try {
        const results = await fetchOptions(searchTerm);
        setOptions(results || []);
        setHighlightedIndex(results && results.length > 0 ? 0 : -1);
      } catch (err) {
        console.error("AsyncSelect fetch error", err);
        setOptions([]);
      } finally {
        setLoading(false);
      }
    }, 300);

    return () => clearTimeout(debounceRef.current);
  }, [searchTerm, isOpen, fetchOptions]);

  useEffect(() => {
    function handleClickOutside(event) {
      if (wrapperRef.current && !wrapperRef.current.contains(event.target)) {
        setIsOpen(false);
      }
    }
    document.addEventListener("mousedown", handleClickOutside);
    return () => document.removeEventListener("mousedown", handleClickOutside);
  }, []);

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
    if (isOpen && highlightedIndex >= 0 && optionRefs.current[highlightedIndex]) {
      optionRefs.current[highlightedIndex].scrollIntoView({
        block: 'nearest',
      });
    }
  }, [highlightedIndex, isOpen, options]);

  const advanceFocus = () => {
    if (nextFocusId) {
      setTimeout(() => {
        const nextEl = document.getElementById(nextFocusId);
        if (nextEl) nextEl.focus();
      }, 100);
    }
  };

  const handleSelect = (opt) => {
    setSelectedOptionCache(opt);
    onChange(opt.value, opt);
    setSearchTerm('');
    setIsOpen(false);
    advanceFocus();
  };

  const handleClear = (e) => {
    e.stopPropagation();
    onChange('', null);
    setSelectedOptionCache(null);
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
          advanceFocus();
        } else {
          setIsOpen(true);
        }
      }
      return;
    }

    switch (e.key) {
      case 'ArrowDown':
        e.preventDefault();
        setHighlightedIndex(prev => prev < options.length - 1 ? prev + 1 : prev);
        break;
      case 'ArrowUp':
        e.preventDefault();
        setHighlightedIndex(prev => (prev > 0 ? prev - 1 : 0));
        break;
      case 'Enter':
        if (highlightedIndex >= 0 && highlightedIndex < options.length) {
          e.preventDefault();
          handleSelect(options[highlightedIndex]);
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
            autoComplete="off"
            spellCheck="false"
            autoCorrect="off"
            autoCapitalize="none"
          />
        )}

        <div className="flex items-center gap-1 text-slate-400 ml-2 shrink-0">
          {loading ? (
            <Loader2 size={16} className="animate-spin text-indigo-500" />
          ) : (
            <>
              {value && (
                <button type="button" onClick={handleClear} className="hover:text-rose-500 transition-colors p-1" tabIndex={-1}>
                  <X size={14} />
                </button>
              )}
              <ChevronDown size={16} className={`transition-transform duration-200 ${isOpen ? 'rotate-180' : ''}`} />
            </>
          )}
        </div>
      </div>

      {isOpen && (
        <div className="absolute top-full left-0 right-0 mt-1 bg-white border border-slate-200 rounded-lg shadow-xl z-50 max-h-60 overflow-y-auto" ref={listboxRef}>
          {loading && options.length === 0 ? (
            <div className="px-3 py-4 text-center text-sm text-slate-500 flex items-center justify-center gap-2">
              <Loader2 size={14} className="animate-spin" /> Searching...
            </div>
          ) : options.length > 0 ? (
            options.map((opt, index) => (
              <div
                key={opt.value}
                ref={el => optionRefs.current[index] = el}
                className={`px-3 py-2 cursor-pointer text-sm transition-colors
                  ${index === highlightedIndex ? 'bg-indigo-50 text-indigo-700' : 'text-slate-700 hover:bg-slate-50'}
                  ${opt.value === value ? 'font-bold bg-indigo-50/50' : ''}
                `}
                onClick={() => handleSelect(opt)}
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
});
