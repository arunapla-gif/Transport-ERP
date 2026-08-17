import React, { useMemo } from 'react';
import { IndianRupee, Package, FileText, CheckCircle2 } from 'lucide-react';

export default function ReportKpiBar({ activeTab, reportData }) {
  const kpis = useMemo(() => {
    if (!reportData || reportData.length === 0) return null;

    let totalFreight = 0;
    let totalArticles = 0;
    let totalValue = 0;
    let deliveredCount = 0;

    if (activeTab === 'gc') {
      reportData.forEach(row => {
        totalFreight += parseFloat(row.Freight || 0);
        totalArticles += parseInt(row.Articles || 0, 10);
        if (row.Status === 'Delivered') deliveredCount++;
      });

      return [
        { label: 'Total Freight', value: `₹${totalFreight.toLocaleString('en-IN', { minimumFractionDigits: 2 })}`, icon: IndianRupee, color: 'text-indigo-600', bg: 'bg-indigo-50', border: 'border-indigo-100' },
        { label: 'Total Articles', value: totalArticles.toLocaleString('en-IN'), icon: Package, color: 'text-amber-600', bg: 'bg-amber-50', border: 'border-amber-100' },
        { label: 'Documents', value: reportData.length, icon: FileText, color: 'text-blue-600', bg: 'bg-blue-50', border: 'border-blue-100' },
        { label: 'Delivered', value: deliveredCount, icon: CheckCircle2, color: 'text-emerald-600', bg: 'bg-emerald-50', border: 'border-emerald-100' },
      ];
    }

    if (activeTab === 'gdm') {
      let totalGcs = 0;
      reportData.forEach(row => {
        const freightStr = row.Freight ? row.Freight.replace(/[^0-9.]/g, '') : '0';
        totalFreight += parseFloat(freightStr || 0);
        totalGcs += parseInt(row['Total GCs'] || 0, 10);
      });

      return [
        { label: 'Total GDM Freight', value: `₹${totalFreight.toLocaleString('en-IN', { minimumFractionDigits: 2 })}`, icon: IndianRupee, color: 'text-emerald-600', bg: 'bg-emerald-50', border: 'border-emerald-100' },
        { label: 'Total GCs Linked', value: totalGcs, icon: FileText, color: 'text-indigo-600', bg: 'bg-indigo-50', border: 'border-indigo-100' },
        { label: 'Total GDMs', value: reportData.length, icon: Package, color: 'text-blue-600', bg: 'bg-blue-50', border: 'border-blue-100' },
      ];
    }

    if (activeTab === 'ewaybill') {
      reportData.forEach(row => {
        totalValue += parseFloat(row['Inv Value'] || 0);
      });
      return [
        { label: 'Total Invoice Value', value: `₹${totalValue.toLocaleString('en-IN', { minimumFractionDigits: 2 })}`, icon: IndianRupee, color: 'text-emerald-600', bg: 'bg-emerald-50', border: 'border-emerald-100' },
        { label: 'Total Records', value: reportData.length, icon: FileText, color: 'text-slate-600', bg: 'bg-slate-50', border: 'border-slate-100' },
      ];
    }

    return null;
  }, [activeTab, reportData]);

  if (!kpis) return null;

  return (
    <div className="grid grid-cols-2 md:grid-cols-4 gap-4 mb-4">
      {kpis.map((kpi, index) => {
        const Icon = kpi.icon;
        return (
          <div key={index} className={`flex items-center gap-4 p-4 rounded-xl border ${kpi.bg} ${kpi.border} shadow-sm`}>
            <div className={`p-3 rounded-lg bg-white shadow-sm ${kpi.color}`}>
              <Icon size={24} />
            </div>
            <div>
              <p className="text-[11px] font-extrabold text-slate-500 uppercase tracking-wider">{kpi.label}</p>
              <h3 className={`text-xl font-black ${kpi.color} tracking-tight leading-none mt-1`}>{kpi.value}</h3>
            </div>
          </div>
        );
      })}
    </div>
  );
}
