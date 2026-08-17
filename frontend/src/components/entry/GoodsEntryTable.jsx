import React from 'react';
import { useFormContext, useFieldArray } from 'react-hook-form';
import { GlassCard, DenseInput, DenseSelect } from '../ui/DensePrimitives';
import { Button } from '../ui/Button';
import { Package, Plus, Trash2 } from 'lucide-react';

export const GoodsRow = React.memo(({ index, isLast, branch, unitHierarchy, allUnitOptions, getUnitBadge, addRow, removeRow, canRemove }) => {
  const { register, setValue, watch, getValues } = useFormContext();
  
  // Watch necessary fields for dynamic updates
  const unitCategory = watch(`goods.${index}.unitCategory`);
  const units = watch(`goods.${index}.units`);
  const weight = watch(`goods.${index}.weight`);
  const rate = watch(`goods.${index}.rate`);
  const description = watch(`goods.${index}.description`);
  const articles = watch(`goods.${index}.articles`);
  const amount = branch === 'BNG' ? ((parseFloat(weight) || 0) * (parseFloat(rate) || 0)) : 0;
  return (
    <div className={`grid ${branch === 'BNG' ? 'grid-cols-[60px_180px_100px_1fr_80px_80px_80px_60px]' : 'grid-cols-[60px_100px_180px_100px_1fr_80px]'} gap-2 p-1 rounded-lg focus-within:bg-indigo-50/80 focus-within:ring-1 focus-within:ring-indigo-500 transition-colors duration-300 focus-within:shadow-[0_4px_20px_rgb(79,70,229,0.12)] focus-within:z-10 relative border border-transparent bg-white/40 hover:bg-white/80`}>
      <DenseInput type="number" autoFocus={getValues(`goods.${index}.isNew`)} {...register(`goods.${index}.articles`)} />
      
      {branch !== 'BNG' && (
        <DenseSelect 
          {...register(`goods.${index}.unitCategory`, {
            onChange: (e) => {
              const newCat = e.target.value;
              const defaultItem = unitHierarchy[newCat] ? unitHierarchy[newCat][0] : null;
              const defaultDesc = defaultItem ? defaultItem.label : '';
              const defaultHsn = defaultItem?.hsn || '';
              const defaultGoodsDesc = defaultItem?.goodsDesc || '';
              const currentHsn = getValues(`goods.${index}.hsn`);
              const currentDesc = getValues(`goods.${index}.description`);
              setValue(`goods.${index}.units`, defaultDesc);
              setValue(`goods.${index}.hsn`, (!currentHsn || currentHsn.trim() === '') ? defaultHsn : currentHsn);
              setValue(`goods.${index}.description`, (!currentDesc || currentDesc.trim() === '') ? defaultGoodsDesc : currentDesc);
            }
          })}
          options={Object.keys(unitHierarchy).map(k => ({ value: k, label: k }))} 
        />
      )}

      <DenseSelect 
        {...register(`goods.${index}.units`, {
          onChange: (e) => {
            const newUnitDesc = e.target.value;
            const match = allUnitOptions.find(o => o.label === newUnitDesc);
            const defaultHsn = match?.hsn || '';
            const defaultGoodsDesc = match?.goodsDesc || '';
            const currentHsn = getValues(`goods.${index}.hsn`);
            const currentDesc = getValues(`goods.${index}.description`);
            if (branch !== 'BNG') {
              setValue(`goods.${index}.hsn`, (!currentHsn || currentHsn.trim() === '') ? defaultHsn : currentHsn);
              setValue(`goods.${index}.description`, (!currentDesc || currentDesc.trim() === '') ? defaultGoodsDesc : currentDesc);
            }
          }
        })}
        options={branch === 'BNG' 
          ? [ { value: '', label: 'Select...' }, ...allUnitOptions.map(u => ({ value: u.label, label: u.label })) ]
          : (unitHierarchy[unitCategory || 'Cases'] || []).map(u => ({ value: u.label, label: u.label }))} 
      />
      <DenseInput {...register(`goods.${index}.hsn`)} />
      <div className="flex items-center gap-1 w-full">
        <DenseInput className="flex-1" {...register(`goods.${index}.description`)} 
          onKeyDown={(e) => {
            if (branch !== 'BNG' && (e.key === 'Enter' || e.key === 'Tab') && isLast) {
              if (description?.trim() !== '' || articles !== '') {
                e.preventDefault();
                addRow();
              } else if (e.key === 'Enter') {
                e.preventDefault();
                document.getElementById('freight-remarks')?.focus();
              }
            }
          }}/>
        {branch !== 'BNG' && getUnitBadge(units)}
      </div>
      {branch === 'BNG' && (
        <>
          <DenseInput type="number" {...register(`goods.${index}.weight`)} />
          <DenseInput type="number" {...register(`goods.${index}.rate`)} 
          onKeyDown={(e) => {
            if ((e.key === 'Enter' || e.key === 'Tab') && isLast) {
              if (rate !== '' || weight !== '') {
                e.preventDefault();
                addRow();
              } else if (e.key === 'Enter') {
                e.preventDefault();
                document.getElementById('freight-remarks')?.focus();
              }
            }
          }}/>
          <div className="flex items-center justify-center font-mono font-bold text-sm bg-slate-50 border border-slate-200 rounded px-2">
             {amount}
          </div>
        </>
      )}
      <div className="flex gap-1 justify-center items-center">
        <Button variant="custom" type="button" tabIndex="-1" onClick={addRow} className="h-9 w-9 p-0 flex items-center justify-center rounded-lg bg-slate-100 text-slate-800 hover:bg-slate-200 shadow-sm transition-colors"><Plus size={16} /></Button>
        <Button variant="custom" type="button" tabIndex="-1" onClick={() => removeRow(index)} disabled={!canRemove} className="h-9 w-9 p-0 flex items-center justify-center rounded-lg bg-slate-100 text-rose-500 hover:text-rose-600 hover:bg-rose-50 shadow-sm transition-colors disabled:opacity-50"><Trash2 size={16} /></Button>
      </div>
    </div>
  );
});

export const GoodsEntryTable = React.memo(({ 
  branch, 
  partyDetails, 
  setPartyDetails, 
  fetchedEwbDetails,
  unitHierarchy,
  allUnitOptions,
  getUnitBadge
}) => {
  const { control } = useFormContext();
  const { fields, append, remove } = useFieldArray({
    control,
    name: "goods"
  });

  const addRow = React.useCallback(() => {
    const defaultItem = unitHierarchy['Cases'] ? unitHierarchy['Cases'][0] : null;
    const newIndex = fields.length;
    append({ 
      id: Date.now(), 
      articles: '', 
      unitCategory: branch === 'BNG' ? '' : 'Cases', 
      units: branch === 'BNG' ? '' : (defaultItem ? defaultItem.label : 'Cases of Fireworks'), 
      hsn: branch === 'BNG' ? '' : (defaultItem?.hsn || ''), 
      description: branch === 'BNG' ? '' : (defaultItem?.goodsDesc || ''), 
      weight: '', 
      rate: '', 
      amount: 0, 
      isNew: true 
    });
    // Aggressively focus the new row after it renders
    setTimeout(() => {
      const inputs = document.querySelectorAll(`input[name="goods.${newIndex}.articles"]`);
      if (inputs.length > 0) inputs[0].focus();
    }, 50);
  }, [append, branch, unitHierarchy, fields.length]);
  return (
    <GlassCard className="flex-1 flex flex-col">
       <div className="flex justify-between items-center mb-3 border-b border-slate-100 pb-2">
         <h3 className="font-bold text-sm text-slate-800 flex items-center gap-2"><Package size={16} className="text-amber-500"/> Goods & Invoice Details</h3>
         <div className="flex gap-4 items-center">
            <DenseInput label="Inv No" value={partyDetails.invoiceNumber} onChange={e => setPartyDetails(prev => ({...prev, invoiceNumber: e.target.value}))} className="w-24 [&>input]:h-7" />
            <DenseInput label="Inv Date" type="date" value={partyDetails.invoiceDate} onChange={e => setPartyDetails(prev => ({...prev, invoiceDate: e.target.value}))} className="w-32 [&>input]:h-7" />
            <DenseInput label="Value ₹" type="number" value={partyDetails.invoiceValue} onChange={e => setPartyDetails(prev => ({...prev, invoiceValue: e.target.value}))} className="w-24 [&>input]:h-7 [&>input]:bg-amber-50" />
            <DenseInput label="Weight" type="text" value={partyDetails.actualWeight} onChange={e => setPartyDetails(prev => ({...prev, actualWeight: e.target.value}))} className="w-24 [&>input]:h-7" />
         </div>
       </div>
       
       {/* EWB PREVIEW HINT */}
       {fetchedEwbDetails?.rawData?.itemList && fetchedEwbDetails.rawData.itemList.length > 0 && (
         <div className="mb-4 relative overflow-hidden bg-gradient-to-r from-indigo-50/90 to-violet-50/90 border border-indigo-200/60 rounded-xl p-3 shadow-sm transition-all duration-500">
           {/* Magic Shimmer Effect */}
           <div className="absolute top-0 left-[-100%] w-1/2 h-full bg-gradient-to-r from-transparent via-white/60 to-transparent skew-x-12 animate-[shimmer_2s_infinite]" />
           
           <div className="flex items-center gap-2 mb-2 relative z-10">
             <span className="bg-gradient-to-r from-indigo-600 to-violet-600 text-white text-[9px] font-black tracking-wider px-2 py-0.5 rounded uppercase shadow-sm">✨ EWB Data Auto-Filled</span>
             <span className="text-xs font-bold text-indigo-900">Type actual physical packages below.</span>
           </div>
           <div className="space-y-1.5 relative z-10">
             {fetchedEwbDetails.rawData.itemList.map((item, idx) => (
               <div key={idx} className="flex flex-wrap gap-2 text-xs font-medium text-indigo-800/80 items-center">
                 <span className="font-bold text-indigo-900">• EWB Item {idx + 1}:</span> 
                 <span className="bg-white/60 px-1.5 rounded border border-indigo-100">{item.quantity} {item.qtyUnit}</span>
                 <span>{item.productName}</span>
                 <span className="text-indigo-600/70 text-[10px] ml-auto">(HSN: {item.hsnCode})</span>
               </div>
             ))}
           </div>
         </div>
       )}
       
        <div className={`grid ${branch === 'BNG' ? 'grid-cols-[60px_180px_100px_1fr_80px_80px_80px_60px]' : 'grid-cols-[60px_100px_180px_100px_1fr_80px]'} gap-2 mb-1 px-2 py-1 bg-slate-100/50 rounded-lg text-center border border-slate-200/50`}>
         <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Qty</div>
         {branch !== 'BNG' && <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Unit</div>}
         <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">{branch === 'BNG' ? 'Unit' : 'Unit Desc'}</div>
         <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">HSN</div>
         <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Description of Goods</div>
         {branch === 'BNG' && (
           <>
             <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Weight</div>
             <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Rate</div>
             <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider">Amount</div>
           </>
         )}
         <div></div>
      </div>
      
      <div className="space-y-1">
        {fields.map((field, index) => (
          <GoodsRow 
            key={field.id}
            index={index}
            isLast={index === fields.length - 1}
            branch={branch}
            unitHierarchy={unitHierarchy}
            allUnitOptions={allUnitOptions}
            getUnitBadge={getUnitBadge}
            addRow={addRow}
            removeRow={remove}
            canRemove={fields.length > 1}
          />
        ))}
      </div>
    </GlassCard>
  );
});
