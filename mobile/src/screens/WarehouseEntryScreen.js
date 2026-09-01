import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  Text,
  View,
  TextInput,
  TouchableOpacity,
  ScrollView,
  ActivityIndicator,
  Alert,
  SafeAreaView,
  StatusBar
} from 'react-native';
import { api } from '../services/api';
import { sendWhatsAppReceipt } from '../utils/whatsapp';

export default function WarehouseEntryScreen() {
  const [ewayBillNo, setEwayBillNo] = useState('');
  const [consignorName, setConsignorName] = useState('');
  const [consigneeName, setConsigneeName] = useState('');
  const [consigneeCity, setConsigneeCity] = useState('');
  const [articles, setArticles] = useState('');
  const [godownNo, setGodownNo] = useState('');
  const [remarks, setRemarks] = useState('');
  const [consignorPhone, setConsignorPhone] = useState('');

  const [loading, setLoading] = useState(false);
  const [fetchingEwb, setFetchingEwb] = useState(false);
  const [recentEntry, setRecentEntry] = useState(null);

  useEffect(() => {
    fetchLastEntry();
  }, []);

  const fetchLastEntry = async () => {
    try {
      const data = await api.get('/warehouse-inward?limit=1');
      if (Array.isArray(data) && data.length > 0) {
        setRecentEntry(data[0]);
      } else if (data && data.data && data.data.length > 0) {
        setRecentEntry(data.data[0]);
      }
    } catch (err) {
      console.log('Fetch last entry info:', err.message);
    }
  };

  const handleFetchEwb = async () => {
    if (!ewayBillNo.trim()) {
      Alert.alert('Required', 'Please enter an E-Way Bill Number');
      return;
    }
    try {
      setFetchingEwb(true);
      const cleanNo = ewayBillNo.trim().replace(/\s+/g, '');
      const ewbData = await api.get(`/ewaybill/${cleanNo}`);
      
      if (ewbData.fromTrdName) setConsignorName(ewbData.fromTrdName.trim().toUpperCase());
      if (ewbData.toTrdName) setConsigneeName(ewbData.toTrdName.trim().toUpperCase());
      if (ewbData.toPlace) setConsigneeCity(ewbData.toPlace.trim().toUpperCase());
      if (ewbData.itemList && ewbData.itemList.length > 0) {
        const totalQty = ewbData.itemList.reduce((sum, i) => sum + (parseInt(i.quantity) || 0), 0);
        setArticles(totalQty.toString());
      }
      Alert.alert('Success', 'E-Way Bill details auto-filled!');
    } catch (err) {
      Alert.alert('Fetch Error', err.message || 'Could not fetch E-Way Bill details.');
    } finally {
      setFetchingEwb(false);
    }
  };

  const handleSaveInward = async () => {
    if (!consignorName || !consigneeName || !articles || !godownNo) {
      Alert.alert('Mandatory Fields', 'Please fill Consignor, Consignee, Articles, and Godown No.');
      return;
    }

    const payload = {
      ewayBillNo,
      consignorName,
      consigneeName,
      consigneeCity,
      articles: parseInt(articles) || 0,
      godownNo,
      remarks
    };

    try {
      setLoading(true);
      const savedEntry = await api.post('/warehouse-inward', payload);
      
      setRecentEntry(savedEntry);
      Alert.alert('Saved!', `Inward Receipt #${savedEntry.receiptNo} created successfully.`);

      // Send WhatsApp Receipt automatically or prompt
      sendWhatsAppReceipt(savedEntry, consignorPhone);

      // Clear Form
      setEwayBillNo('');
      setConsignorName('');
      setConsigneeName('');
      setConsigneeCity('');
      setArticles('');
      setGodownNo('');
      setRemarks('');
      setConsignorPhone('');
    } catch (err) {
      Alert.alert('Save Failed', err.message || 'Could not save inward entry.');
    } finally {
      setLoading(false);
    }
  };

  return (
    <SafeAreaView style={styles.container}>
      <StatusBar barStyle="light-content" backgroundColor="#0f172a" />
      
      {/* Header */}
      <View style={styles.header}>
        <Text style={styles.headerTitle}>Arunachalam ERP</Text>
        <Text style={styles.headerSubtitle}>Warehouse Mobile Inward</Text>
      </View>

      <ScrollView contentContainerStyle={styles.scrollContent} keyboardShouldPersistTaps="handled">
        
        {/* EWB Search Card */}
        <View style={styles.card}>
          <Text style={styles.label}>Scan / Enter E-Way Bill No.</Text>
          <View style={styles.row}>
            <TextInput
              style={[styles.input, { flex: 1 }]}
              placeholder="e.g. 1234 5678 9012"
              value={ewayBillNo}
              onChangeText={setEwayBillNo}
              keyboardType="number-pad"
            />
            <TouchableOpacity 
              style={styles.fetchBtn} 
              onPress={handleFetchEwb} 
              disabled={fetchingEwb}
            >
              {fetchingEwb ? (
                <ActivityIndicator color="#fff" size="small" />
              ) : (
                <Text style={styles.btnText}>Fetch</Text>
              )}
            </TouchableOpacity>
          </View>
        </View>

        {/* Form Inputs */}
        <View style={styles.card}>
          <Text style={styles.sectionTitle}>Inward Details</Text>

          <Text style={styles.label}>Consignor Name (From) *</Text>
          <TextInput
            style={styles.input}
            placeholder="Sender / Company Name"
            value={consignorName}
            onChangeText={setConsignorName}
            autoCapitalize="characters"
          />

          <Text style={styles.label}>Consignee Name (To) *</Text>
          <TextInput
            style={styles.input}
            placeholder="Receiver Name"
            value={consigneeName}
            onChangeText={setConsigneeName}
            autoCapitalize="characters"
          />

          <Text style={styles.label}>Consignee City</Text>
          <TextInput
            style={styles.input}
            placeholder="City / Destination"
            value={consigneeCity}
            onChangeText={setConsigneeCity}
            autoCapitalize="characters"
          />

          <View style={styles.row}>
            <View style={{ flex: 1, marginRight: 8 }}>
              <Text style={styles.label}>Total Articles *</Text>
              <TextInput
                style={styles.input}
                placeholder="Qty"
                value={articles}
                onChangeText={setArticles}
                keyboardType="numeric"
              />
            </View>
            <View style={{ flex: 1, marginLeft: 8 }}>
              <Text style={styles.label}>Godown No *</Text>
              <TextInput
                style={styles.input}
                placeholder="e.g. G-1"
                value={godownNo}
                onChangeText={setGodownNo}
                autoCapitalize="characters"
              />
            </View>
          </View>

          <Text style={styles.label}>Consignor Phone (for WhatsApp)</Text>
          <TextInput
            style={styles.input}
            placeholder="10-digit Mobile Number"
            value={consignorPhone}
            onChangeText={setConsignorPhone}
            keyboardType="phone-pad"
            maxLength={10}
          />

          <Text style={styles.label}>Remarks / Item Description</Text>
          <TextInput
            style={[styles.input, { height: 70 }]}
            placeholder="Optional remarks..."
            value={remarks}
            onChangeText={setRemarks}
            multiline
          />

          {/* Submit Button */}
          <TouchableOpacity 
            style={styles.saveBtn} 
            onPress={handleSaveInward} 
            disabled={loading}
          >
            {loading ? (
              <ActivityIndicator color="#fff" size="small" />
            ) : (
              <Text style={styles.saveBtnText}>📥 SAVE INWARD ENTRY</Text>
            )}
          </TouchableOpacity>
        </View>

        {/* Recent Entry Card with WhatsApp Trigger */}
        {recentEntry && (
          <View style={[styles.card, styles.recentCard]}>
            <View style={styles.recentHeader}>
              <Text style={styles.recentTitle}>Last Saved Receipt #{recentEntry.receiptNo}</Text>
              <Text style={styles.recentBadge}>SAVED</Text>
            </View>

            <Text style={styles.recentText}>🏢 From: {recentEntry.consignorName}</Text>
            <Text style={styles.recentText}>👤 To: {recentEntry.consigneeName} {recentEntry.consigneeCity ? `(${recentEntry.consigneeCity})` : ''}</Text>
            <Text style={styles.recentText}>📦 Articles: {recentEntry.articles} Box(es) | Godown: {recentEntry.godownNo}</Text>

            {/* Native WhatsApp Trigger Button */}
            <TouchableOpacity 
              style={styles.whatsappBtn} 
              onPress={() => sendWhatsAppReceipt(recentEntry, consignorPhone)}
            >
              <Text style={styles.whatsappBtnText}>📱 SEND WHATSAPP RECEIPT</Text>
            </TouchableOpacity>
          </View>
        )}

      </ScrollView>
    </SafeAreaView>
  );
}

const styles = StyleSheet.create({
  container: {
    flex: 1,
    backgroundColor: '#f8fafc'
  },
  header: {
    backgroundColor: '#0f172a',
    paddingVertical: 18,
    paddingHorizontal: 20,
    borderBottomLeftRadius: 16,
    borderBottomRightRadius: 16
  },
  headerTitle: {
    color: '#38bdf8',
    fontSize: 22,
    fontWeight: '900',
    letterSpacing: 0.5
  },
  headerSubtitle: {
    color: '#94a3b8',
    fontSize: 13,
    fontWeight: '600',
    marginTop: 2
  },
  scrollContent: {
    padding: 16,
    paddingBottom: 40
  },
  card: {
    backgroundColor: '#ffffff',
    borderRadius: 16,
    padding: 16,
    marginBottom: 16,
    shadowColor: '#000',
    shadowOffset: { width: 0, height: 2 },
    shadowOpacity: 0.05,
    shadowRadius: 8,
    elevation: 3,
    borderWidth: 1,
    borderColor: '#e2e8f0'
  },
  sectionTitle: {
    fontSize: 16,
    fontWeight: '800',
    color: '#1e293b',
    marginBottom: 14
  },
  label: {
    fontSize: 11,
    fontWeight: '700',
    color: '#64748b',
    textTransform: 'uppercase',
    marginBottom: 6,
    marginTop: 8
  },
  input: {
    backgroundColor: '#f8fafc',
    borderWidth: 1.5,
    borderColor: '#cbd5e1',
    borderRadius: 10,
    paddingHorizontal: 12,
    paddingVertical: 10,
    fontSize: 15,
    fontWeight: '600',
    color: '#0f172a'
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center'
  },
  fetchBtn: {
    backgroundColor: '#4f46e5',
    borderRadius: 10,
    paddingHorizontal: 20,
    paddingVertical: 12,
    marginLeft: 10,
    justifyContent: 'center',
    alignItems: 'center'
  },
  btnText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '800'
  },
  saveBtn: {
    backgroundColor: '#10b981',
    borderRadius: 12,
    paddingVertical: 14,
    marginTop: 20,
    alignItems: 'center',
    shadowColor: '#10b981',
    shadowOffset: { width: 0, height: 4 },
    shadowOpacity: 0.3,
    shadowRadius: 6,
    elevation: 4
  },
  saveBtnText: {
    color: '#ffffff',
    fontSize: 15,
    fontWeight: '900',
    letterSpacing: 0.5
  },
  recentCard: {
    backgroundColor: '#f0fdf4',
    borderColor: '#bbf7d0',
    borderWidth: 1.5
  },
  recentHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginBottom: 8
  },
  recentTitle: {
    fontSize: 15,
    fontWeight: '900',
    color: '#166534'
  },
  recentBadge: {
    backgroundColor: '#22c55e',
    color: '#ffffff',
    fontSize: 10,
    fontWeight: '900',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: 6
  },
  recentText: {
    fontSize: 13,
    fontWeight: '700',
    color: '#15803d',
    marginBottom: 4
  },
  whatsappBtn: {
    backgroundColor: '#25d366',
    borderRadius: 10,
    paddingVertical: 12,
    marginTop: 12,
    alignItems: 'center',
    flexDirection: 'row',
    justifyContent: 'center'
  },
  whatsappBtnText: {
    color: '#ffffff',
    fontSize: 14,
    fontWeight: '900',
    letterSpacing: 0.5
  }
});
