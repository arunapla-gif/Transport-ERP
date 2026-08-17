import { useState } from 'react';
import { api } from '../api';

export function useEwayBillProcessor({ branch }) {
  const [isFetchingEwb, setIsFetchingEwb] = useState(false);

  const fetchEwayBill = async (ewayBillNo, currentCompanyMode) => {
    if (!ewayBillNo || !ewayBillNo.trim()) return null;
    
    setIsFetchingEwb(true);
    try {
      const cleanEwbNo = ewayBillNo.trim().replace(/\s+/g, '');
      const ewbData = await api.get(`/ewaybill/${cleanEwbNo}?company=${currentCompanyMode === 'B' ? 'BELL' : 'AP'}`);
      
      let cnorId = '';
      let cnorPreview = [ewbData.fromAddr1, ewbData.fromAddr2, ewbData.fromPlace].filter(Boolean).join(', ') + (ewbData.fromPincode ? ` - ${ewbData.fromPincode}` : '') + (ewbData.fromStateCode ? ` (State: ${ewbData.fromStateCode})` : '');
      
      let matchedConsignor = null;
      if (ewbData.fromGstin || ewbData.fromTrdName) {
         const cnorRes = await api.get(`/consignors/search?branch=${branch}&q=${encodeURIComponent(ewbData.fromGstin || ewbData.fromTrdName)}`);
         matchedConsignor = cnorRes.find(c => (c.gstin && ewbData.fromGstin && c.gstin.toLowerCase() === ewbData.fromGstin.toLowerCase()) || c.name.toLowerCase() === ewbData.fromTrdName?.toLowerCase());
      }

      let isNewCnor = false;
      if (matchedConsignor) {
        cnorId = matchedConsignor.id.toString();
        cnorPreview = [matchedConsignor.address, matchedConsignor.city, matchedConsignor.pincode].filter(Boolean).join(', ') + (matchedConsignor.state ? ` (State: ${matchedConsignor.state})` : '');
      } else if (ewbData.fromTrdName) {
        try {
          const newCnor = await api.post('/consignors', {
            name: ewbData.fromTrdName.replace(/\s+/g, ' ').trim(),
            gstin: ewbData.fromGstin ? ewbData.fromGstin.toUpperCase() : '',
            address: [ewbData.fromAddr1, ewbData.fromAddr2].filter(Boolean).join(', '),
            city: ewbData.fromPlace || ewbData.fromAddr2 || '',
            state: ewbData.fromStateCode ? ewbData.fromStateCode.toString() : '',
            pincode: ewbData.fromPincode ? ewbData.fromPincode.toString() : '',
            migrationType: 'EWB_LITE'
          });
          matchedConsignor = newCnor;
          cnorId = newCnor.id.toString();
          cnorPreview = [newCnor.address, newCnor.city, newCnor.pincode].filter(Boolean).join(', ') + (newCnor.state ? ` (State: ${newCnor.state})` : '');
          isNewCnor = true;
        } catch (e) {
          console.error("Auto-create consignor failed", e);
        }
      }

      let cneeId = '';
      let cneePreview = [ewbData.toAddr1, ewbData.toAddr2, ewbData.toPlace].filter(Boolean).join(', ') + (ewbData.toPincode ? ` - ${ewbData.toPincode}` : '') + (ewbData.toStateCode ? ` (State: ${ewbData.toStateCode})` : '');
      
      let matchedConsignee = null;
      if (ewbData.toGstin || ewbData.toTrdName) {
         const cneeRes = await api.get(`/consignees/search?branch=${branch}&q=${encodeURIComponent(ewbData.toGstin || ewbData.toTrdName)}`);
         matchedConsignee = cneeRes.find(c => (c.gstin && ewbData.toGstin && c.gstin.toLowerCase() === ewbData.toGstin.toLowerCase()) || c.name.toLowerCase() === ewbData.toTrdName?.toLowerCase());
      }

      let isNewCnee = false;
      if (matchedConsignee) {
        cneeId = matchedConsignee.id.toString();
        cneePreview = [matchedConsignee.address, matchedConsignee.city, matchedConsignee.pincode].filter(Boolean).join(', ') + (matchedConsignee.state ? ` (State: ${matchedConsignee.state})` : '');
      } else if (ewbData.toTrdName) {
        try {
          const newCnee = await api.post('/consignees', {
            name: ewbData.toTrdName.replace(/\s+/g, ' ').trim(),
            gstin: ewbData.toGstin ? ewbData.toGstin.toUpperCase() : '',
            address: [ewbData.toAddr1, ewbData.toAddr2].filter(Boolean).join(', '),
            city: ewbData.toPlace || ewbData.toAddr2 || '',
            state: ewbData.toStateCode ? ewbData.toStateCode.toString() : '',
            pincode: ewbData.toPincode ? ewbData.toPincode.toString() : '',
            migrationType: 'EWB_LITE'
          });
          matchedConsignee = newCnee;
          cneeId = newCnee.id.toString();
          cneePreview = [newCnee.address, newCnee.city, newCnee.pincode].filter(Boolean).join(', ') + (newCnee.state ? ` (State: ${newCnee.state})` : '');
          isNewCnee = true;
        } catch (e) {
          console.error("Auto-create consignee failed", e);
        }
      }
      
      // Parse DD/MM/YYYY to YYYY-MM-DD
      let parsedDate = null;
      const rawDate = ewbData.docDate || ewbData.documentDate;
      if (rawDate) {
        if (rawDate.includes('/')) {
          const parts = rawDate.split('/');
          if (parts.length === 3) {
            parsedDate = `${parts[2]}-${parts[1]}-${parts[0]}`;
          }
        } else if (rawDate.includes('-') && rawDate.split('-')[0].length === 2) {
          const parts = rawDate.split('-');
          parsedDate = `${parts[2]}-${parts[1]}-${parts[0]}`;
        } else {
          parsedDate = rawDate;
        }
      }

      return {
        success: true,
        ewbData,
        cleanEwbNo,
        detectedCompany: ewbData.detectedCompany,
        partyUpdates: {
          consignorId: cnorId,
          consignorGstin: ewbData.fromGstin || '',
          consignorAddressPreview: cnorPreview,
          consignorData: matchedConsignor,
          isNewConsignor: isNewCnor,
          consigneeId: cneeId,
          consigneeGstin: ewbData.toGstin || '',
          consigneeAddressPreview: cneePreview,
          consigneeData: matchedConsignee,
          isNewConsignee: isNewCnee,
          invoiceDate: parsedDate,
          invoiceNumber: ewbData.docNo || ewbData.documentNo,
          invoiceValue: ewbData.totInvValue ? ewbData.totInvValue.toString() : null,
          privateMark: cleanEwbNo
        }
      };
    } catch (err) {
      console.error('Failed to fetch EWB:', err);
      return { success: false, error: err };
    } finally {
      setIsFetchingEwb(false);
    }
  };

  return { fetchEwayBill, isFetchingEwb };
}
