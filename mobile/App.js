import React from 'react';
import { SafeAreaProvider } from 'react-native-safe-area-context';
import WarehouseEntryScreen from './src/screens/WarehouseEntryScreen';

export default function App() {
  return (
    <SafeAreaProvider>
      <WarehouseEntryScreen />
    </SafeAreaProvider>
  );
}
