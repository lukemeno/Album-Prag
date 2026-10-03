import { useEffect, useState } from 'react';
import { StyleSheet, Text, View } from 'react-native';
import { Image } from 'expo-image';
import type { SQLiteDatabase } from 'expo-sqlite';
import type { Place } from '@/domain/place';
import { externalAsset, imageAsset, imageRemoteURL, uploadedAsset } from '@/domain/place-images';
import { cacheRemotePlaceImage, localImageURI } from '@/storage/place-media';
import { colors } from '@/domain/theme';

const bundledPhotos: Record<string, number> = {
  imgSculpture: require('../../assets/native-photos/imgSculpture.png'),
  imgThumbCafe: require('../../assets/native-photos/imgThumbCafe.png'),
  imgThumbLetna: require('../../assets/native-photos/imgThumbLetna.png'),
  imgPhotoLetna: require('../../assets/native-photos/imgPhotoLetna.png'),
  imgPhotoOldTown: require('../../assets/native-photos/imgPhotoOldTown.png'),
  imgThumbOldTown: require('../../assets/native-photos/imgThumbOldTown.png'),
  imgPhotoCharlesBridge: require('../../assets/native-photos/imgPhotoCharlesBridge.png'),
};

export function PlacePhoto({ asset, db, placeID, size = 180, label = 'Ortsfoto' }: { asset: Place['image']; db?: SQLiteDatabase; placeID?: string; size?: number; label?: string }) {
  const [uri, setURI] = useState<string | null>(null);
  const [loadedID, setLoadedID] = useState<string | null>(null);
  const uploaded = uploadedAsset(asset);
  const uploadedID = uploaded?.id ?? null;
  const storagePath = uploaded?.storagePath ?? null;
  useEffect(() => {
    let active = true;
    if (!db || !uploadedID) return () => { active = false; };
    void (async () => {
      let value = await localImageURI(db, uploadedID);
      if (!value && storagePath && placeID) value = await cacheRemotePlaceImage(db, uploadedID, placeID, storagePath);
      if (active) { setURI(value); setLoadedID(uploadedID); }
    })().catch(() => { if (active) { setURI(null); setLoadedID(uploadedID); } });
    return () => { active = false; };
  }, [db, placeID, storagePath, uploadedID]);
  const parsed = imageAsset(asset);
  const source = (parsed && 'bundled' in parsed ? bundledPhotos[parsed.bundled.name] : null) || (uploaded && loadedID === uploaded.id ? uri : null) || imageRemoteURL(asset);
  const external = externalAsset(asset);
  const credit = external?.credit || (parsed && 'linkPreview' in parsed ? parsed.linkPreview.credit || '' : '');
  if (!source) return <View accessible accessibilityLabel={`${label}: kein Foto`} style={[styles.empty, { height: size }]}><Text style={styles.emptyText}>Kein Foto</Text></View>;
  return <View style={{ height: size }}><Image accessibilityLabel={label} contentFit="cover" cachePolicy="memory-disk" source={typeof source === 'number' ? source : { uri: source }} style={styles.image} /><Text numberOfLines={1} style={styles.credit}>{credit}</Text></View>;
}

const styles = StyleSheet.create({ image: { backgroundColor: colors.paperDeep, borderRadius: 14, height: '100%', width: '100%' }, empty: { alignItems: 'center', backgroundColor: colors.paperDeep, borderRadius: 14, justifyContent: 'center', width: '100%' }, emptyText: { color: colors.inkSoft, fontSize: 13 }, credit: { bottom: 5, color: colors.card, fontSize: 10, left: 8, position: 'absolute', right: 8, textShadowColor: '#0008', textShadowRadius: 3 } });
