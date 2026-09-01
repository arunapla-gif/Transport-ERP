import { Linking, Alert } from 'react-native';

/**
 * Sends formatted WhatsApp Receipt directly on Android device
 */
export const sendWhatsAppReceipt = async (entry, consignorPhone = '') => {
  if (!entry) return;

  const receiptNo = entry.receiptNo || 'N/A';
  const consignorName = entry.consignorName || 'N/A';
  const consigneeName = entry.consigneeName || 'N/A';
  const consigneeCity = entry.consigneeCity ? `(${entry.consigneeCity})` : '';
  const articles = entry.articles || 0;
  const godownNo = entry.godownNo || 'N/A';
  const ewayBillNo = entry.ewayBillNo || '';
  const remarks = entry.remarks || '';
  const dateStr = entry.createdAt ? new Date(entry.createdAt).toLocaleDateString('en-IN') : new Date().toLocaleDateString('en-IN');

  const message = 
`📦 *ARUNACHALAM TRANSPORT ERP*
*Warehouse Inward Receipt #${receiptNo}*
----------------------------------------
📅 *Date*: ${dateStr}
🏢 *From*: ${consignorName}
👤 *To*: ${consigneeName} ${consigneeCity}
📦 *Total Articles*: *${articles} Box(es)*
${ewayBillNo ? `📄 *E-Way Bill*: ${ewayBillNo}\n` : ''}${remarks ? `💬 *Remarks*: ${remarks}\n` : ''}
----------------------------------------
✅ *Inward Stock Received at Warehouse*
⚠️ *Note: Final confirmation subject to office verification.*`;

  const cleanPhone = consignorPhone ? consignorPhone.replace(/\D/g, '') : '';
  const url = cleanPhone 
    ? `https://wa.me/91${cleanPhone}?text=${encodeURIComponent(message)}` 
    : `https://wa.me/?text=${encodeURIComponent(message)}`;

  try {
    const canOpen = await Linking.canOpenURL(url);
    if (canOpen) {
      await Linking.openURL(url);
    } else {
      // Fallback direct open
      await Linking.openURL(`whatsapp://send?text=${encodeURIComponent(message)}`);
    }
  } catch (err) {
    Alert.alert(
      'WhatsApp Share',
      'Could not open WhatsApp directly. Opening browser link...',
      [{ text: 'OK', onPress: () => Linking.openURL(url) }]
    );
  }
};
