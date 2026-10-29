import React, { useState, useEffect } from 'react';
import {
  StyleSheet,
  View,
  Text,
  TextInput,
  TouchableOpacity,
  ActivityIndicator,
  Alert,
  Linking,
  Share,
  Modal,
  Image,
} from 'react-native';
import { useAuth } from '../context/AuthContext';
import { colors, spacing, radius } from '../theme/theme';
import { ServerAPI, DEFAULT_CUSTOMER_REFERRAL_SETTINGS } from '../services/api';
import { CustomerReferralSettings, CustomerReferralRecord } from '../types';

export const ProfileScreen: React.FC = () => {
  const { customer, updateProfile, updateLocation, changePassword, logout, resetPasswordByMobile, isLoading } = useAuth();

  // Basic Profile Form State
  const [name, setName] = useState<string>(customer?.name || '');
  const [mobile, setMobile] = useState<string>(customer?.mobile || '');
  const [alternateMobile, setAlternateMobile] = useState<string>(customer?.alternate_mobile || customer?.alt_mobile || '');
  const [address, setAddress] = useState<string>(customer?.address || '');

  // Location Form State
  const [area, setArea] = useState<string>(customer?.area || 'Anna Nagar');
  const [city, setCity] = useState<string>(customer?.city || 'Chennai');
  const [pincode, setPincode] = useState<string>(customer?.pincode || '600040');
  const [latitude, setLatitude] = useState<string>(customer?.latitude ? String(customer.latitude) : '13.0827');
  const [longitude, setLongitude] = useState<string>(customer?.longitude ? String(customer.longitude) : '80.2707');
  const [isGettingGps, setIsGettingGps] = useState<boolean>(false);

  // Interactive Map Location Picker State
  const [showLocationModal, setShowLocationModal] = useState<boolean>(false);
  const [tempArea, setTempArea] = useState<string>(customer?.area || 'Anna Nagar');
  const [tempCity, setTempCity] = useState<string>(customer?.city || 'Chennai');
  const [tempPincode, setTempPincode] = useState<string>(customer?.pincode || '600040');
  const [tempLatitude, setTempLatitude] = useState<string>(customer?.latitude ? String(customer.latitude) : '13.0827');
  const [tempLongitude, setTempLongitude] = useState<string>(customer?.longitude ? String(customer.longitude) : '80.2707');

  const PRESET_ZONES = [
    { name: 'Anna Nagar', city: 'Chennai', pincode: '600040', lat: '13.0850', lng: '80.2101' },
    { name: 'T. Nagar', city: 'Chennai', pincode: '600017', lat: '13.0418', lng: '80.2341' },
    { name: 'Adyar', city: 'Chennai', pincode: '600020', lat: '13.0012', lng: '80.2565' },
    { name: 'Velachery', city: 'Chennai', pincode: '600042', lat: '12.9791', lng: '80.2185' },
    { name: 'Kilpauk', city: 'Chennai', pincode: '600010', lat: '13.0784', lng: '80.2415' },
    { name: 'Mylapore', city: 'Chennai', pincode: '600004', lat: '13.0368', lng: '80.2676' },
    { name: 'OMR Perungudi', city: 'Chennai', pincode: '600096', lat: '12.9654', lng: '80.2461' },
    { name: 'Porur', city: 'Chennai', pincode: '600116', lat: '13.0382', lng: '80.1565' },
  ];

  // Password Form & Reset Modal State
  const [oldPassword, setOldPassword] = useState<string>('');
  const [newPassword, setNewPassword] = useState<string>('');
  const [confirmPassword, setConfirmPassword] = useState<string>('');
  const [showPasswordSection, setShowPasswordSection] = useState<boolean>(false);
  const [showResetModal, setShowResetModal] = useState<boolean>(false);
  const [resetMobileOrId, setResetMobileOrId] = useState<string>(customer?.mobile || customer?.customer_id || '');

  // Support Query Modal State
  const [showSupportModal, setShowSupportModal] = useState<boolean>(false);
  const [supportTopic, setSupportTopic] = useState<string>('Delivery Schedule');
  const [supportMessage, setSupportMessage] = useState<string>('');

  // Server-based Referral State (Customer Referral Only)
  const [referralSettings, setReferralSettings] = useState<CustomerReferralSettings>(DEFAULT_CUSTOMER_REFERRAL_SETTINGS);
  const [myReferrals, setMyReferrals] = useState<CustomerReferralRecord[]>([]);
  const [isLoadingReferrals, setIsLoadingReferrals] = useState<boolean>(false);
  const [showReferModal, setShowReferModal] = useState<boolean>(false);
  const [friendName, setFriendName] = useState<string>('');
  const [friendMobile, setFriendMobile] = useState<string>('');
  const [friendArea, setFriendArea] = useState<string>(customer?.area || 'Anna Nagar');
  const [isSubmittingReferral, setIsSubmittingReferral] = useState<boolean>(false);
  const [showReferralHistory, setShowReferralHistory] = useState<boolean>(false);

  useEffect(() => {
    loadReferralData();
  }, [customer?.customer_id]);

  const loadReferralData = async () => {
    if (!customer?.customer_id) return;
    setIsLoadingReferrals(true);
    try {
      const [settingsData, refList] = await Promise.all([
        ServerAPI.fetchReferralSettings(),
        ServerAPI.fetchCustomerReferrals(customer.customer_id)
      ]);
      setReferralSettings(settingsData);
      setMyReferrals(refList);
    } catch (_) {}
    setIsLoadingReferrals(false);
  };

  const myReferralCode = `AMU-${(customer?.customer_id || customer?.id || 'CUST').replace(/[^a-zA-Z0-9]/g, '').toUpperCase()}`;

  const handleCopyReferralCode = async () => {
    if (typeof navigator !== 'undefined' && (navigator as any).clipboard) {
      try {
        await (navigator as any).clipboard.writeText(myReferralCode);
        Alert.alert('Code Copied!', `Your referral code "${myReferralCode}" has been copied to your clipboard.`);
        return;
      } catch (_) {}
    }
    Alert.alert('Your Referral Code', myReferralCode);
  };

  const handleShareReferral = async () => {
    if (!customer) return;
    const shareMessage = referralSettings.customer_share_message
      .replace('{code}', myReferralCode)
      .replace('{discount}', String(referralSettings.customer_referee_discount_value))
      .replace('{reward}', String(referralSettings.customer_referrer_reward_value))
      .replace('{name}', customer.name || 'Friend')
      .replace('{link}', referralSettings.app_download_url);

    try {
      if (typeof navigator !== 'undefined' && (navigator as any).clipboard) {
        await (navigator as any).clipboard.writeText(shareMessage);
        Alert.alert('Invite Link Copied', 'Referral message copied to clipboard! Share it with your friends on WhatsApp or SMS:\n\n' + shareMessage);
      } else {
        await Share.share({
          message: shareMessage,
          title: referralSettings.customer_offer_title || 'Invite Friends to Amutham Milk',
        });
      }
    } catch (_) {
      Alert.alert('Share Referral', shareMessage);
    }
  };

  const handleSubmitDirectReferral = async () => {
    if (!customer) return;
    if (!friendName.trim() || !friendMobile.trim()) {
      Alert.alert('Missing Details', 'Please provide your friend\'s full name and mobile number.');
      return;
    }
    const cleanPhone = friendMobile.replaceAll(/[^0-9]/g, '');
    if (cleanPhone.length < 10) {
      Alert.alert('Invalid Mobile', 'Please enter a valid 10-digit mobile number.');
      return;
    }

    setIsSubmittingReferral(true);
    const res = await ServerAPI.submitCustomerReferral({
      referrer_id: customer.customer_id,
      referrer_name: customer.name,
      referrer_phone: customer.mobile,
      referral_code: myReferralCode,
      referee_name: friendName.trim(),
      referee_phone: cleanPhone,
      referee_area: friendArea.trim(),
    });
    setIsSubmittingReferral(false);

    if (res.success) {
      setShowReferModal(false);
      setFriendName('');
      setFriendMobile('');
      Alert.alert('🎉 Referral Registered', res.message || 'Your referral has been saved on the server!');
      loadReferralData();
    } else {
      Alert.alert('Referral Notice', res.message || 'Failed to submit referral. Please try again.');
    }
  };

  if (!customer) return null;

  const handleFetchCurrentGPS = async (forModal = false) => {
    if (typeof navigator !== 'undefined' && navigator.geolocation) {
      setIsGettingGps(true);
      navigator.geolocation.getCurrentPosition(
        async (pos) => {
          setIsGettingGps(false);
          const latStr = pos.coords.latitude.toFixed(6);
          const lngStr = pos.coords.longitude.toFixed(6);

          if (forModal) {
            setTempLatitude(latStr);
            setTempLongitude(lngStr);
          } else {
            setLatitude(latStr);
            setLongitude(lngStr);
          }

          // Reverse geocoding via Google Maps Geocoding API
          try {
            const res = await fetch(`https://maps.googleapis.com/maps/api/geocode/json?latlng=${latStr},${lngStr}&key=AIzaSyBDy9hy20F8UTS8URDJfDMrQeXQOoSpNH4`);
            const data = await res.json();
            if (data && data.results && data.results.length > 0) {
              const first = data.results[0];
              const components = first.address_components || [];
              let detectedArea = '';
              let detectedCity = '';
              let detectedPin = '';

              for (const comp of components) {
                const types = comp.types || [];
                if (types.includes('sublocality_level_1') || types.includes('sublocality') || types.includes('neighborhood')) {
                  if (!detectedArea) detectedArea = comp.long_name;
                } else if (types.includes('locality') || types.includes('administrative_area_level_2')) {
                  if (!detectedCity) detectedCity = comp.long_name;
                } else if (types.includes('postal_code')) {
                  detectedPin = comp.long_name;
                }
              }

              if (forModal) {
                if (detectedArea) setTempArea(detectedArea);
                if (detectedCity) setTempCity(detectedCity);
                if (detectedPin) setTempPincode(detectedPin);
              } else {
                if (detectedArea) setArea(detectedArea);
                if (detectedCity) setCity(detectedCity);
                if (detectedPin) setPincode(detectedPin);
              }
            }
          } catch (_) {}

          Alert.alert('GPS Location Pinned', `Coordinates: ${latStr}, ${lngStr}\nDelivery location updated.`);
        },
        (err) => {
          setIsGettingGps(false);
          Alert.alert('GPS Notice', err.message || 'Unable to fetch current device location.');
        },
        { enableHighAccuracy: true, timeout: 10000 }
      );
    } else {
      Alert.alert('GPS Not Available', 'Geolocation is not supported in this browser/device.');
    }
  };

  const handleOpenLocationModal = () => {
    setTempArea(area);
    setTempCity(city);
    setTempPincode(pincode);
    setTempLatitude(latitude);
    setTempLongitude(longitude);
    setShowLocationModal(true);
  };

  const handleConfirmLocationModal = async () => {
    setArea(tempArea);
    setCity(tempCity);
    setPincode(tempPincode);
    setLatitude(tempLatitude);
    setLongitude(tempLongitude);
    setShowLocationModal(false);

    const latNum = parseFloat(tempLatitude) || 13.0827;
    const lngNum = parseFloat(tempLongitude) || 80.2707;

    await updateLocation({
      address: address.trim(),
      area: tempArea.trim(),
      city: tempCity.trim(),
      pincode: tempPincode.trim(),
      latitude: latNum,
      longitude: lngNum,
    });
  };

  const handleSaveProfile = async () => {
    if (!name.trim() || !mobile.trim() || !address.trim()) {
      Alert.alert('Required Fields', 'Please fill in Full Name, Mobile Number, and Street Address.');
      return;
    }
    await updateProfile(name.trim(), mobile.trim(), address.trim(), alternateMobile.trim());
  };

  const handleSaveLocation = async () => {
    if (!area.trim() || !city.trim() || !pincode.trim()) {
      Alert.alert('Required Fields', 'Please specify Area, City, and Pincode.');
      return;
    }
    const latNum = parseFloat(latitude) || 13.0827;
    const lngNum = parseFloat(longitude) || 80.2707;
    const pin = pincode.trim();

    const isServiceable = await ServerAPI.isPincodeServiceable(pin);
    if (!isServiceable) {
      await ServerAPI.recordUnserviceableLocationRequest({
        pincode: pin,
        areaName: area.trim(),
        city: city.trim(),
        customerName: name.trim(),
        customerMobile: mobile.trim(),
        fullAddress: address.trim(),
        latitude: latNum,
        longitude: lngNum,
        notes: 'Customer updated delivery address with unserviceable pincode',
      });
      Alert.alert(
        'Delivery Notice',
        `“We are not available at your location yet, but we will quickly reach to your location”\n\nYour address update with Pincode ${pin} has been registered with our operations depot. We will notify you when regular routes expand to your area!`,
        [{ text: 'OK' }]
      );
    }

    await updateLocation({
      address: address.trim(),
      area: area.trim(),
      city: city.trim(),
      pincode: pincode.trim(),
      latitude: latNum,
      longitude: lngNum,
    });
  };

  const handleChangePasswordSubmit = async () => {
    if (!oldPassword.trim() || !newPassword.trim()) {
      Alert.alert('Required Fields', 'Please enter Current Password and New Password.');
      return;
    }

    if (newPassword !== confirmPassword) {
      Alert.alert('Password Mismatch', 'New Password and Confirm Password do not match.');
      return;
    }

    const success = await changePassword(oldPassword.trim(), newPassword.trim());
    if (success) {
      setOldPassword('');
      setNewPassword('');
      setConfirmPassword('');
      setShowPasswordSection(false);
    }
  };

  const handleResetPasswordSubmit = async () => {
    if (!resetMobileOrId.trim() || !newPassword.trim()) {
      Alert.alert('Required Fields', 'Please enter Mobile Number / Customer ID and New Password.');
      return;
    }

    if (newPassword !== confirmPassword) {
      Alert.alert('Password Mismatch', 'New Password and Confirm Password do not match.');
      return;
    }

    const success = await resetPasswordByMobile(resetMobileOrId.trim(), newPassword.trim());
    if (success) {
      setNewPassword('');
      setConfirmPassword('');
      setShowResetModal(false);
    }
  };

  const handleOpenGoogleMaps = () => {
    const lat = customer.latitude || parseFloat(latitude) || 13.0827;
    const lng = customer.longitude || parseFloat(longitude) || 80.2707;
    const mapsUrl = `https://www.google.com/maps/search/?api=1&query=${lat},${lng}`;
    Linking.openURL(mapsUrl).catch(() => {
      Alert.alert('Maps Link', `Opening location: ${mapsUrl}`);
    });
  };

  const handleShareLocation = async () => {
    const lat = customer.latitude || parseFloat(latitude) || 13.0827;
    const lng = customer.longitude || parseFloat(longitude) || 80.2707;
    const mapsUrl = `https://maps.google.com/?q=${lat},${lng}`;
    const shareMessage = `Amutham Milk Delivery Address:\n${customer.name} (${customer.customer_id})\n${customer.address}, ${customer.area}, ${customer.city} - ${customer.pincode}\nGoogle Maps: ${mapsUrl}`;

    try {
      if (navigator && (navigator as any).clipboard) {
        await (navigator as any).clipboard.writeText(shareMessage);
        Alert.alert('Location Shared', 'Delivery address & Google Maps link copied to clipboard!\n\n' + shareMessage);
      } else {
        await Share.share({
          message: shareMessage,
          title: 'Delivery Location - Amutham Raw Milk',
        });
      }
    } catch (_) {
      Alert.alert('Share Location', shareMessage);
    }
  };

  const handleCallSupport = () => {
    Linking.openURL('tel:+917331152332').catch(() => {
      Alert.alert('Call Support', 'Dialing support helpline: +91 7331152332');
    });
  };

  const handleWhatsAppSupport = () => {
    const msg = encodeURIComponent(`Hello Amutham Support, I need help with my account (${customer.customer_id}).`);
    Linking.openURL(`https://wa.me/917331152332?text=${msg}`).catch(() => {
      Alert.alert('WhatsApp Support', 'Opening WhatsApp support for +91 7331152332...');
    });
  };

  const handleEmailSupport = () => {
    Linking.openURL('mailto:support@amuthamrawmilk.com').catch(() => {
      Alert.alert('Email Support', 'Contact email: support@amuthamrawmilk.com');
    });
  };

  const handleSubmitSupportQuery = () => {
    if (!supportMessage.trim()) {
      Alert.alert('Empty Message', 'Please enter your message or query.');
      return;
    }
    setShowSupportModal(false);
    setSupportMessage('');
    Alert.alert(
      'Support Request Received',
      `Thank you! Your ticket regarding "${supportTopic}" has been created.\nOur support team will call you back on ${customer.mobile} shortly.`
    );
  };

  const monthlyRate = customer.monthly_rate || Math.round(customer.milk_quantity * 65 * 30);
  const bottleCount = Math.ceil(customer.milk_quantity / 0.75);

  return (
    <View style={styles.container}>
      {/* 1. EDIT PROFILE CARD */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Edit Profile</Text>
        <Text style={styles.cardSub}>Changes will be saved to Supabase server</Text>

        <Text style={styles.inputLabel}>Customer ID (Permanent)</Text>
        <TextInput
          style={[styles.input, styles.readOnlyInput]}
          value={customer.customer_id}
          editable={false}
        />

        <Text style={styles.inputLabel}>Full Name *</Text>
        <TextInput
          style={styles.input}
          value={name}
          onChangeText={setName}
          placeholder="Full Name"
          placeholderTextColor={colors.textLight}
        />

        <Text style={styles.inputLabel}>Primary Mobile Number *</Text>
        <TextInput
          style={styles.input}
          value={mobile}
          onChangeText={setMobile}
          placeholder="+91 Mobile Number"
          placeholderTextColor={colors.textLight}
          keyboardType="phone-pad"
        />

        <Text style={styles.inputLabel}>Alternate Mobile Number (Family / WhatsApp)</Text>
        <TextInput
          style={styles.input}
          value={alternateMobile}
          onChangeText={setAlternateMobile}
          placeholder="e.g. +91 98409 87654 (Optional)"
          placeholderTextColor={colors.textLight}
          keyboardType="phone-pad"
        />

        <Text style={styles.inputLabel}>Street Address *</Text>
        <TextInput
          style={[styles.input, styles.multilineInput]}
          value={address}
          onChangeText={setAddress}
          placeholder="Door No, Flat Name, Street"
          placeholderTextColor={colors.textLight}
          multiline
          numberOfLines={2}
        />

        <TouchableOpacity
          style={[styles.primaryBtn, isLoading && styles.disabledBtn]}
          onPress={handleSaveProfile}
          disabled={isLoading}
          activeOpacity={0.8}
        >
          {isLoading ? (
            <ActivityIndicator color={colors.surface} size="small" />
          ) : (
            <Text style={styles.primaryBtnText}>☁️ Update Profile on Server</Text>
          )}
        </TouchableOpacity>
      </View>

      {/* 2. LOCATION MANAGEMENT & GPS MAP SHARE CARD */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Location & Delivery Address</Text>
        <Text style={styles.cardSub}>Delivery route & map coordinates synced with server</Text>

        <Text style={styles.inputLabel}>Area & City *</Text>
        <View style={styles.rowInputs}>
          <TextInput
            style={[styles.input, { flex: 1 }]}
            value={area}
            onChangeText={setArea}
            placeholder="Area (e.g. Anna Nagar)"
            placeholderTextColor={colors.textLight}
          />
          <TextInput
            style={[styles.input, { flex: 1 }]}
            value={city}
            onChangeText={setCity}
            placeholder="City (e.g. Chennai)"
            placeholderTextColor={colors.textLight}
          />
        </View>

        <Text style={styles.inputLabel}>Pincode *</Text>
        <TextInput
          style={styles.input}
          value={pincode}
          onChangeText={setPincode}
          placeholder="600040"
          placeholderTextColor={colors.textLight}
          keyboardType="numeric"
        />

        {/* MAP PINPOINT & CURRENT LOCATION SELECTION */}
        <View style={styles.mapInfoCard}>
          <View style={{ flex: 1 }}>
            <Text style={styles.mapInfoTitle}>📍 Delivery Pin Status</Text>
            <Text style={styles.mapInfoSub}>
              {area}, {city} - {pincode}
            </Text>
            <Text style={styles.mapInfoCoords}>
              Coordinates: {latitude}, {longitude}
            </Text>
          </View>
          <TouchableOpacity onPress={() => handleFetchCurrentGPS(false)} style={styles.gpsAutoBtn}>
            <Text style={styles.gpsAutoBtnText}>
              {isGettingGps ? '⏳ Locating...' : '🎯 My GPS'}
            </Text>
          </TouchableOpacity>
        </View>

        {/* INTERACTIVE MAP PICKER TRIGGER */}
        <TouchableOpacity
          style={styles.mapPickerModalBtn}
          onPress={handleOpenLocationModal}
          activeOpacity={0.8}
        >
          <Text style={styles.mapPickerModalBtnText}>🗺️ Pick / Modify Location on Map & Confirm</Text>
        </TouchableOpacity>

        <TouchableOpacity
          style={[styles.secondaryBtn, { marginTop: spacing.sm }]}
          onPress={handleSaveLocation}
          disabled={isLoading}
        >
          <Text style={styles.secondaryBtnText}>📍 Save Location Settings</Text>
        </TouchableOpacity>

        {/* MAP SHARE ACTION BUTTONS */}
        <View style={styles.mapActionRow}>
          <TouchableOpacity style={styles.mapBtn} onPress={handleOpenGoogleMaps} activeOpacity={0.8}>
            <Text style={styles.mapBtnText}>🗺️ Open in Google Maps</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.mapBtnOutline} onPress={handleShareLocation} activeOpacity={0.8}>
            <Text style={styles.mapBtnOutlineText}>📤 Share Location</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* 3. PASSWORD SECURITY CARD */}
      <View style={styles.card}>
        <TouchableOpacity
          style={styles.collapsibleHeader}
          onPress={() => setShowPasswordSection(!showPasswordSection)}
          activeOpacity={0.8}
        >
          <Text style={styles.cardTitle}>🔒 Security & Password Reset</Text>
          <Text style={{ fontSize: 16, color: colors.primary }}>
            {showPasswordSection ? '▲' : '▼'}
          </Text>
        </TouchableOpacity>

        {showPasswordSection ? (
          <View style={{ marginTop: spacing.md }}>
            <Text style={styles.inputLabel}>Current Password *</Text>
            <TextInput
              style={styles.input}
              value={oldPassword}
              onChangeText={setOldPassword}
              secureTextEntry
              placeholder="Enter current password"
              placeholderTextColor={colors.textLight}
            />

            <Text style={styles.inputLabel}>New Password *</Text>
            <TextInput
              style={styles.input}
              value={newPassword}
              onChangeText={setNewPassword}
              secureTextEntry
              placeholder="Enter new password"
              placeholderTextColor={colors.textLight}
            />

            <Text style={styles.inputLabel}>Confirm New Password *</Text>
            <TextInput
              style={styles.input}
              value={confirmPassword}
              onChangeText={setConfirmPassword}
              secureTextEntry
              placeholder="Confirm new password"
              placeholderTextColor={colors.textLight}
            />

            <TouchableOpacity
              style={[styles.primaryBtn, { marginTop: spacing.lg }]}
              onPress={handleChangePasswordSubmit}
              disabled={isLoading}
            >
              {isLoading ? (
                <ActivityIndicator color={colors.surface} size="small" />
              ) : (
                <Text style={styles.primaryBtnText}>Update Password on Server</Text>
              )}
            </TouchableOpacity>

            <TouchableOpacity
              onPress={() => setShowResetModal(true)}
              style={styles.forgotBtn}
            >
              <Text style={styles.forgotBtnText}>Forgot Password? Reset via Mobile / Customer ID</Text>
            </TouchableOpacity>
          </View>
        ) : (
          <Text style={styles.cardSub}>Tap to expand, change password, or trigger password reset.</Text>
        )}
      </View>

      {/* 4. ACCOUNT DETAILS DISPLAY (MATCHING REFERENCE UI) */}
      <View style={styles.card}>
        <Text style={styles.cardTitle}>Account Details</Text>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>📱 Primary Mobile</Text>
          <Text style={styles.detailVal}>{customer.mobile || 'Not Set'}</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>📞 Alternate Mobile</Text>
          <Text style={styles.detailVal}>
            {customer.alternate_mobile || customer.alt_mobile || alternateMobile || 'Not Provided'}
          </Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>🏙️ Delivery Area</Text>
          <Text style={styles.detailVal}>{customer.area || area || 'Anna Nagar'}</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>📍 City</Text>
          <Text style={styles.detailVal}>{customer.city || city || 'Chennai'}</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>📮 Pincode</Text>
          <Text style={styles.detailVal}>{customer.pincode || pincode || '600040'}</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>🕒 Delivery Slot</Text>
          <Text style={styles.detailVal}>{customer.delivery_timing || '5:00 AM - 9:30 AM'}</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>🥛 Milk Type</Text>
          <Text style={styles.detailVal}>{customer.milk_type || 'Pure Cow Milk (A2)'}</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>🥛 Daily Quantity</Text>
          <Text style={styles.detailVal}>{customer.milk_quantity} L ({bottleCount} bottles)</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>💰 Monthly Rate</Text>
          <Text style={styles.detailValGreen}>₹{monthlyRate.toLocaleString()}</Text>
        </View>

        <View style={styles.detailRow}>
          <Text style={styles.detailLabel}>🗺️ Delivery Pin</Text>
          <Text style={styles.detailVal}>
            {customer.latitude || latitude || 13.0827}, {customer.longitude || longitude || 80.2707}
          </Text>
        </View>
      </View>

      {/* 5. REFER & EARN CARD (CUSTOMER REFERRAL ONLY) */}
      <View style={[styles.card, styles.referralCard]}>
        <View style={styles.referralHeaderRow}>
          <View style={styles.referralIconCircle}>
            <Text style={{ fontSize: 22 }}>🎁</Text>
          </View>
          <View style={{ flex: 1 }}>
            <Text style={styles.cardTitle}>{referralSettings.customer_offer_title}</Text>
            <Text style={styles.cardSub}>{referralSettings.customer_offer_tagline}</Text>
          </View>
        </View>

        {/* Server Offer Highlight Pill */}
        <View style={styles.referralOfferBanner}>
          <Text style={styles.referralOfferBannerTitle}>
            Give ₹{referralSettings.customer_referee_discount_value} OFF • Earn ₹{referralSettings.customer_referrer_reward_value} Milk Credit
          </Text>
          <Text style={styles.referralOfferBannerSub}>
            {referralSettings.customer_offer_terms}
          </Text>
        </View>

        {/* Referral Code Row */}
        <Text style={styles.inputLabel}>Your Unique Customer Referral Code</Text>
        <View style={styles.referralCodeBox}>
          <Text style={styles.referralCodeText}>{myReferralCode}</Text>
          <TouchableOpacity style={styles.copyCodeBtn} onPress={handleCopyReferralCode} activeOpacity={0.8}>
            <Text style={styles.copyCodeBtnText}>📋 Copy</Text>
          </TouchableOpacity>
        </View>

        {/* Referral Actions */}
        <View style={styles.referralActionsRow}>
          <TouchableOpacity style={styles.shareInviteBtn} onPress={handleShareReferral} activeOpacity={0.8}>
            <Text style={styles.shareInviteBtnText}>📲 Share Invite Link</Text>
          </TouchableOpacity>

          <TouchableOpacity style={styles.directReferBtn} onPress={() => setShowReferModal(true)} activeOpacity={0.8}>
            <Text style={styles.directReferBtnText}>📝 Direct Refer Friend</Text>
          </TouchableOpacity>
        </View>

        {/* Collapsible Referrals History */}
        <TouchableOpacity
          style={styles.historyToggleRow}
          onPress={() => setShowReferralHistory(!showReferralHistory)}
          activeOpacity={0.8}
        >
          <Text style={styles.historyToggleText}>
            👥 My Referrals History ({myReferrals.length})
          </Text>
          <Text style={styles.historyToggleArrow}>
            {showReferralHistory ? '▲ Hide' : '▼ View'}
          </Text>
        </TouchableOpacity>

        {showReferralHistory && (
          <View style={styles.historyContentWrap}>
            {isLoadingReferrals ? (
              <ActivityIndicator color={colors.primary} size="small" style={{ marginVertical: spacing.md }} />
            ) : myReferrals.length === 0 ? (
              <View style={styles.emptyHistoryBox}>
                <Text style={styles.emptyHistoryText}>
                  No referrals yet. Share your code with neighbors to earn ₹{referralSettings.customer_referrer_reward_value} on their first subscription!
                </Text>
              </View>
            ) : (
              myReferrals.map((item) => (
                <View key={item.id} style={styles.historyCardRow}>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.historyRefereeName}>{item.referee_name}</Text>
                    <Text style={styles.historyRefereePhone}>
                      📞 {item.referee_phone} {item.referee_area ? `• ${item.referee_area}` : ''}
                    </Text>
                    <Text style={styles.historyDate}>
                      {new Date(item.created_at).toLocaleDateString('en-IN', { day: '2-digit', month: 'short', year: 'numeric' })}
                    </Text>
                  </View>
                  <View style={{ alignItems: 'flex-end' }}>
                    <Text style={[
                      styles.historyStatusPill,
                      item.status === 'REWARDED' ? styles.statusPillRewarded :
                      item.status === 'QUALIFIED' ? styles.statusPillQualified : styles.statusPillPending
                    ]}>
                      {item.status}
                    </Text>
                    <Text style={styles.historyRewardAmount}>
                      +₹{item.reward_amount}
                    </Text>
                  </View>
                </View>
              ))
            )}
          </View>
        )}
      </View>

      {/* 6. CONTACT OUR SUPPORT TEAM CARD */}
      <View style={[styles.card, styles.supportCard]}>
        <Text style={styles.cardTitle}>🎧 Contact Support Team</Text>
        <Text style={styles.cardSub}>Our customer care team is available daily 6:00 AM – 9:00 PM</Text>

        <View style={styles.supportList}>
          <TouchableOpacity style={styles.supportBtn} onPress={handleCallSupport} activeOpacity={0.8}>
            <Text style={styles.supportBtnIcon}>📞</Text>
            <View style={{ flex: 1 }}>
              <Text style={styles.supportBtnTitle}>Call Customer Helpline</Text>
              <Text style={styles.supportBtnSub}>+91 7331152332</Text>
            </View>
          </TouchableOpacity>

          <TouchableOpacity style={styles.supportBtnWhatsapp} onPress={handleWhatsAppSupport} activeOpacity={0.8}>
            <Text style={styles.supportBtnIcon}>💬</Text>
            <View style={{ flex: 1 }}>
              <Text style={styles.supportBtnTitleWhite}>WhatsApp Support</Text>
              <Text style={styles.supportBtnSubWhite}>Chat instantly with customer care</Text>
            </View>
          </TouchableOpacity>

          <TouchableOpacity style={styles.supportBtn} onPress={handleEmailSupport} activeOpacity={0.8}>
            <Text style={styles.supportBtnIcon}>✉️</Text>
            <View style={{ flex: 1 }}>
              <Text style={styles.supportBtnTitle}>Email Support Desk</Text>
              <Text style={styles.supportBtnSub}>support@amuthamrawmilk.com</Text>
            </View>
          </TouchableOpacity>

          <TouchableOpacity
            style={styles.queryModalBtn}
            onPress={() => setShowSupportModal(true)}
            activeOpacity={0.8}
          >
            <Text style={styles.queryModalBtnText}>📝 Submit Support Ticket / Request Callback</Text>
          </TouchableOpacity>
        </View>
      </View>

      {/* 6. LOGOUT BUTTON CARD */}
      <View style={styles.card}>
        <TouchableOpacity style={styles.logoutBtn} onPress={logout} activeOpacity={0.8}>
          <Text style={styles.logoutBtnText}>🚪 Logout from Account</Text>
        </TouchableOpacity>
      </View>

      {/* RESET PASSWORD MODAL */}
      <Modal visible={showResetModal} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Reset Account Password</Text>
            <Text style={styles.modalSubtitle}>Enter your Mobile Number or Customer ID to reset password on Supabase server.</Text>

            <Text style={styles.inputLabel}>Mobile Number or Customer ID *</Text>
            <TextInput
              style={styles.input}
              value={resetMobileOrId}
              onChangeText={setResetMobileOrId}
              placeholder="Mobile Number or Customer ID"
              placeholderTextColor={colors.textLight}
            />

            <Text style={styles.inputLabel}>New Password *</Text>
            <TextInput
              style={styles.input}
              value={newPassword}
              onChangeText={setNewPassword}
              secureTextEntry
              placeholder="New password"
              placeholderTextColor={colors.textLight}
            />

            <Text style={styles.inputLabel}>Confirm New Password *</Text>
            <TextInput
              style={styles.input}
              value={confirmPassword}
              onChangeText={setConfirmPassword}
              secureTextEntry
              placeholder="Confirm new password"
              placeholderTextColor={colors.textLight}
            />

            <View style={styles.modalActions}>
              <TouchableOpacity style={styles.cancelModalBtn} onPress={() => setShowResetModal(false)}>
                <Text style={styles.cancelModalBtnText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity style={styles.submitModalBtn} onPress={handleResetPasswordSubmit}>
                <Text style={styles.submitModalBtnText}>Reset Password</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* SUPPORT QUERY MODAL */}
      <Modal visible={showSupportModal} transparent animationType="fade">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <Text style={styles.modalTitle}>Submit Support Request</Text>
            <Text style={styles.modalSubtitle}>Our support executive will review your request and get back to you.</Text>

            <Text style={styles.inputLabel}>Topic / Category</Text>
            <View style={styles.topicRow}>
              {['Delivery Schedule', 'Milk Quantity', 'Billing / UPI', 'Quality'].map((t) => (
                <TouchableOpacity
                  key={t}
                  style={[styles.topicChip, supportTopic === t && styles.topicChipActive]}
                  onPress={() => setSupportTopic(t)}
                >
                  <Text style={[styles.topicChipText, supportTopic === t && styles.topicChipTextActive]}>{t}</Text>
                </TouchableOpacity>
              ))}
            </View>

            <Text style={styles.inputLabel}>Your Message / Request Details *</Text>
            <TextInput
              style={[styles.input, styles.multilineInput, { height: 90 }]}
              value={supportMessage}
              onChangeText={setSupportMessage}
              placeholder="Describe your issue or query here..."
              placeholderTextColor={colors.textLight}
              multiline
            />

            <View style={styles.modalActions}>
              <TouchableOpacity style={styles.cancelModalBtn} onPress={() => setShowSupportModal(false)}>
                <Text style={styles.cancelModalBtnText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity style={styles.submitModalBtn} onPress={handleSubmitSupportQuery}>
                <Text style={styles.submitModalBtnText}>Submit Ticket</Text>
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
      {/* 7. INTERACTIVE MAP LOCATION SELECTION & CONFIRM MODAL */}
      <Modal visible={showLocationModal} transparent animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={[styles.modalContent, { maxWidth: 480 }]}>
            <View style={styles.modalHeaderRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.modalTitle}>🗺️ Select Delivery Location</Text>
                <Text style={styles.modalSubtitle}>
                  Choose your area or locate via GPS, then tap Confirm Location.
                </Text>
              </View>
              <TouchableOpacity onPress={() => setShowLocationModal(false)} style={styles.closeModalBtn}>
                <Text style={styles.closeModalBtnText}>✕</Text>
              </TouchableOpacity>
            </View>

            {/* GPS AUTO-LOCATE BUTTON */}
            <TouchableOpacity
              style={styles.gpsCenterBtn}
              onPress={() => handleFetchCurrentGPS(true)}
              activeOpacity={0.8}
            >
              <Text style={styles.gpsCenterBtnText}>
                {isGettingGps ? '⏳ Locating GPS...' : '🎯 Center on My Current GPS Location'}
              </Text>
            </TouchableOpacity>

            {/* PRESET CHIPS */}
            <Text style={[styles.inputLabel, { marginTop: spacing.sm }]}>Popular Delivery Zones:</Text>
            <View style={styles.presetChipsWrap}>
              {PRESET_ZONES.map((zone) => (
                <TouchableOpacity
                  key={zone.name}
                  style={[
                    styles.zoneChip,
                    tempArea === zone.name && styles.zoneChipActive,
                  ]}
                  onPress={() => {
                    setTempArea(zone.name);
                    setTempCity(zone.city);
                    setTempPincode(zone.pincode);
                    setTempLatitude(zone.lat);
                    setTempLongitude(zone.lng);
                  }}
                >
                  <Text
                    style={[
                      styles.zoneChipText,
                      tempArea === zone.name && styles.zoneChipTextActive,
                    ]}
                  >
                    {zone.name}
                  </Text>
                </TouchableOpacity>
              ))}
            </View>

            {/* INTERACTIVE PIN CARD / VISUAL MAP DISPLAY */}
            <View style={styles.interactiveMapCard}>
              {tempLatitude && tempLongitude ? (
                <Image
                  source={{
                    uri: `https://maps.googleapis.com/maps/api/staticmap?center=${tempLatitude},${tempLongitude}&zoom=15&size=600x260&scale=2&maptype=roadmap&markers=color:red%7C${tempLatitude},${tempLongitude}&key=AIzaSyBDy9hy20F8UTS8URDJfDMrQeXQOoSpNH4`,
                  }}
                  style={{ width: '100%', height: 160, borderRadius: 10, marginBottom: 10 }}
                  resizeMode="cover"
                />
              ) : null}
              <View style={styles.mapPinBadge}>
                <Text style={styles.mapPinIcon}>📍</Text>
                <View style={{ flex: 1 }}>
                  <Text style={styles.mapPinArea}>{tempArea}, {tempCity}</Text>
                  <Text style={styles.mapPinPincode}>Pincode: {tempPincode}</Text>
                </View>
              </View>
              <View style={styles.mapCoordsPill}>
                <Text style={styles.mapCoordsText}>
                  GPS Coordinates: {tempLatitude}, {tempLongitude}
                </Text>
              </View>
            </View>

            {/* EDITABLE DETAILS */}
            <Text style={styles.inputLabel}>Confirm Area & City</Text>
            <View style={styles.rowInputs}>
              <TextInput
                style={[styles.input, { flex: 1 }]}
                value={tempArea}
                onChangeText={setTempArea}
                placeholder="Area"
                placeholderTextColor={colors.textLight}
              />
              <TextInput
                style={[styles.input, { flex: 1 }]}
                value={tempCity}
                onChangeText={setTempCity}
                placeholder="City"
                placeholderTextColor={colors.textLight}
              />
            </View>

            <Text style={styles.inputLabel}>Pincode</Text>
            <TextInput
              style={styles.input}
              value={tempPincode}
              onChangeText={setTempPincode}
              placeholder="600040"
              placeholderTextColor={colors.textLight}
              keyboardType="numeric"
            />

            <View style={styles.modalActions}>
              <TouchableOpacity
                style={styles.cancelModalBtn}
                onPress={() => setShowLocationModal(false)}
              >
                <Text style={styles.cancelModalBtnText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={styles.confirmLocationBtn}
                onPress={handleConfirmLocationModal}
                disabled={isLoading}
              >
                {isLoading ? (
                  <ActivityIndicator color={colors.surface} size="small" />
                ) : (
                  <Text style={styles.confirmLocationBtnText}>Confirm Location ✓</Text>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>

      {/* 8. DIRECT FRIEND REFERRAL MODAL */}
      <Modal visible={showReferModal} transparent animationType="slide">
        <View style={styles.modalOverlay}>
          <View style={styles.modalContent}>
            <View style={styles.modalHeaderRow}>
              <View style={{ flex: 1 }}>
                <Text style={styles.modalTitle}>🎁 Refer a Friend / Neighbor</Text>
                <Text style={styles.modalSubtitle}>
                  Enter your friend's details to invite them directly and unlock exclusive discounts.
                </Text>
              </View>
              <TouchableOpacity onPress={() => setShowReferModal(false)} style={styles.closeModalBtn}>
                <Text style={styles.closeModalBtnText}>✕</Text>
              </TouchableOpacity>
            </View>

            <Text style={styles.inputLabel}>Friend's Full Name *</Text>
            <TextInput
              style={styles.input}
              value={friendName}
              onChangeText={setFriendName}
              placeholder="e.g. Ramesh Babu"
              placeholderTextColor={colors.textLight}
            />

            <Text style={styles.inputLabel}>Friend's Mobile Number *</Text>
            <TextInput
              style={styles.input}
              value={friendMobile}
              onChangeText={setFriendMobile}
              placeholder="e.g. 9840123456"
              placeholderTextColor={colors.textLight}
              keyboardType="phone-pad"
            />

            <Text style={styles.inputLabel}>Delivery Area / Locality</Text>
            <TextInput
              style={styles.input}
              value={friendArea}
              onChangeText={setFriendArea}
              placeholder="e.g. Anna Nagar, Chennai"
              placeholderTextColor={colors.textLight}
            />

            <View style={styles.directOfferNote}>
              <Text style={styles.directOfferNoteText}>
                ✨ Your friend will receive a ₹{referralSettings.customer_referee_discount_value} welcome discount on their first month of raw milk, and you will receive ₹{referralSettings.customer_referrer_reward_value} in your Milk Wallet!
              </Text>
            </View>

            <View style={styles.modalActions}>
              <TouchableOpacity style={styles.cancelModalBtn} onPress={() => setShowReferModal(false)}>
                <Text style={styles.cancelModalBtnText}>Cancel</Text>
              </TouchableOpacity>

              <TouchableOpacity
                style={[styles.submitModalBtn, isSubmittingReferral && styles.disabledBtn]}
                onPress={handleSubmitDirectReferral}
                disabled={isSubmittingReferral}
              >
                {isSubmittingReferral ? (
                  <ActivityIndicator color={colors.surface} size="small" />
                ) : (
                  <Text style={styles.submitModalBtnText}>Send Referral</Text>
                )}
              </TouchableOpacity>
            </View>
          </View>
        </View>
      </Modal>
    </View>
  );
};

const styles = StyleSheet.create({
  container: {
    gap: spacing.lg,
  },
  card: {
    backgroundColor: colors.surface,
    padding: spacing.lg,
    borderRadius: radius.lg,
    borderColor: colors.border,
    borderWidth: 1,
  },
  supportCard: {
    borderLeftWidth: 4,
    borderLeftColor: colors.primary,
  },
  cardTitle: {
    fontSize: 16,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  cardSub: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 2,
    marginBottom: spacing.xs,
  },
  collapsibleHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
  },
  inputLabel: {
    fontSize: 12,
    color: colors.textSecondary,
    marginTop: spacing.md,
    marginBottom: 4,
    fontWeight: '600',
  },
  input: {
    backgroundColor: colors.background,
    borderColor: colors.borderDark,
    borderWidth: 1,
    borderRadius: radius.md,
    padding: spacing.md,
    color: colors.textPrimary,
    fontSize: 14,
  },
  readOnlyInput: {
    backgroundColor: '#f1f5f9',
    color: colors.textMuted,
  },
  multilineInput: {
    height: 60,
    textAlignVertical: 'top',
  },
  rowInputs: {
    flexDirection: 'row',
    gap: spacing.sm,
  },
  primaryBtn: {
    backgroundColor: colors.primary,
    padding: spacing.md + 2,
    borderRadius: radius.lg,
    alignItems: 'center',
    marginTop: spacing.md,
  },
  disabledBtn: {
    opacity: 0.7,
  },
  primaryBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 14,
  },
  secondaryBtn: {
    backgroundColor: colors.primaryLight,
    padding: spacing.md,
    borderRadius: radius.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.primaryBorder,
  },
  secondaryBtnText: {
    color: colors.primary,
    fontWeight: '700',
    fontSize: 13,
  },
  mapActionRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  mapBtn: {
    flex: 1,
    backgroundColor: colors.secondary,
    paddingVertical: spacing.md,
    paddingHorizontal: 8,
    borderRadius: radius.md,
    alignItems: 'center',
  },
  mapBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 12,
  },
  mapBtnOutline: {
    flex: 1,
    backgroundColor: colors.background,
    borderColor: colors.borderDark,
    borderWidth: 1,
    paddingVertical: spacing.md,
    paddingHorizontal: 8,
    borderRadius: radius.md,
    alignItems: 'center',
  },
  mapBtnOutlineText: {
    color: colors.textPrimary,
    fontWeight: '700',
    fontSize: 12,
  },
  detailRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.sm + 2,
    borderBottomWidth: 1,
    borderBottomColor: colors.border,
  },
  detailLabel: {
    color: colors.textMuted,
    fontSize: 13,
  },
  detailVal: {
    color: colors.textPrimary,
    fontSize: 13,
    fontWeight: '700',
  },
  detailValGreen: {
    color: colors.statusGreen,
    fontSize: 14,
    fontWeight: '700',
  },
  supportList: {
    gap: spacing.sm,
    marginTop: spacing.md,
  },
  supportBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    backgroundColor: colors.background,
    padding: spacing.md,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: colors.border,
  },
  supportBtnWhatsapp: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    backgroundColor: '#25D366',
    padding: spacing.md,
    borderRadius: radius.md,
  },
  supportBtnIcon: {
    fontSize: 20,
  },
  supportBtnTitle: {
    color: colors.textPrimary,
    fontWeight: '700',
    fontSize: 13,
  },
  supportBtnSub: {
    color: colors.textMuted,
    fontSize: 11,
    marginTop: 1,
  },
  supportBtnTitleWhite: {
    color: '#ffffff',
    fontWeight: '700',
    fontSize: 13,
  },
  supportBtnSubWhite: {
    color: '#e8f5e9',
    fontSize: 11,
    marginTop: 1,
  },
  rowHeader: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    marginTop: spacing.md,
  },
  gpsAutoBtn: {
    backgroundColor: colors.primaryLight,
    paddingHorizontal: 8,
    paddingVertical: 4,
    borderRadius: radius.sm,
  },
  gpsAutoBtnText: {
    color: colors.primary,
    fontSize: 11,
    fontWeight: '700',
  },
  forgotBtn: {
    marginTop: spacing.md,
    alignItems: 'center',
  },
  forgotBtnText: {
    color: colors.primary,
    fontSize: 12,
    fontWeight: '600',
  },
  queryModalBtn: {
    backgroundColor: colors.primaryLight,
    padding: spacing.md,
    borderRadius: radius.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: colors.primaryBorder,
    marginTop: 4,
  },
  queryModalBtnText: {
    color: colors.primary,
    fontWeight: '700',
    fontSize: 13,
  },
  logoutBtn: {
    backgroundColor: '#fee2e2',
    padding: spacing.md + 2,
    borderRadius: radius.md,
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#fca5a5',
  },
  logoutBtnText: {
    color: '#dc2626',
    fontWeight: '800',
    fontSize: 14,
  },
  modalOverlay: {
    flex: 1,
    backgroundColor: 'rgba(15, 23, 42, 0.6)',
    justifyContent: 'center',
    alignItems: 'center',
    padding: spacing.lg,
  },
  modalContent: {
    width: '100%',
    maxWidth: 440,
    backgroundColor: colors.surface,
    borderRadius: radius.xl,
    padding: spacing.xl,
  },
  modalTitle: {
    fontSize: 18,
    fontWeight: '800',
    color: colors.textPrimary,
  },
  modalSubtitle: {
    fontSize: 12,
    color: colors.textMuted,
    marginTop: 4,
    marginBottom: spacing.sm,
  },
  topicRow: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
    marginTop: 4,
  },
  topicChip: {
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
    paddingHorizontal: 10,
    paddingVertical: 6,
    borderRadius: radius.md,
  },
  topicChipActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  topicChipText: {
    color: colors.textSecondary,
    fontSize: 11,
    fontWeight: '600',
  },
  topicChipTextActive: {
    color: colors.surface,
    fontWeight: '700',
  },
  modalActions: {
    flexDirection: 'row',
    gap: spacing.md,
    marginTop: spacing.xl,
  },
  cancelModalBtn: {
    flex: 1,
    padding: spacing.md,
    borderRadius: radius.md,
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.border,
    alignItems: 'center',
  },
  cancelModalBtnText: {
    color: colors.textSecondary,
    fontWeight: '600',
    fontSize: 13,
  },
  submitModalBtn: {
    flex: 1,
    padding: spacing.md,
    borderRadius: radius.md,
    backgroundColor: colors.primary,
    alignItems: 'center',
  },
  submitModalBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 13,
  },
  mapInfoCard: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    backgroundColor: '#f8fafc',
    borderWidth: 1,
    borderColor: '#e2e8f0',
    borderRadius: radius.md,
    padding: spacing.md,
    marginTop: spacing.md,
  },
  mapInfoTitle: {
    fontSize: 12,
    fontWeight: '700',
    color: colors.primary,
  },
  mapInfoSub: {
    fontSize: 13,
    fontWeight: '600',
    color: colors.textPrimary,
    marginTop: 2,
  },
  mapInfoCoords: {
    fontSize: 11,
    color: colors.textMuted,
    marginTop: 2,
  },
  mapPickerModalBtn: {
    backgroundColor: colors.primary,
    paddingVertical: spacing.md,
    paddingHorizontal: spacing.lg,
    borderRadius: radius.md,
    alignItems: 'center',
    marginTop: spacing.md,
  },
  mapPickerModalBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 13,
  },
  modalHeaderRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'flex-start',
  },
  closeModalBtn: {
    padding: spacing.xs,
  },
  closeModalBtnText: {
    fontSize: 18,
    color: colors.textMuted,
    fontWeight: 'bold',
  },
  gpsCenterBtn: {
    backgroundColor: colors.primaryLight,
    borderWidth: 1,
    borderColor: colors.primaryBorder,
    borderRadius: radius.md,
    paddingVertical: spacing.md,
    alignItems: 'center',
    marginTop: spacing.sm,
  },
  gpsCenterBtnText: {
    color: colors.primary,
    fontWeight: '700',
    fontSize: 13,
  },
  presetChipsWrap: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: spacing.xs,
    marginTop: 6,
    marginBottom: spacing.sm,
  },
  zoneChip: {
    backgroundColor: colors.background,
    borderWidth: 1,
    borderColor: colors.borderDark,
    borderRadius: radius.sm,
    paddingHorizontal: 8,
    paddingVertical: 5,
  },
  zoneChipActive: {
    backgroundColor: colors.primary,
    borderColor: colors.primary,
  },
  zoneChipText: {
    fontSize: 11,
    color: colors.textSecondary,
    fontWeight: '600',
  },
  zoneChipTextActive: {
    color: colors.surface,
    fontWeight: '700',
  },
  interactiveMapCard: {
    backgroundColor: '#f1f5f9',
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: '#cbd5e1',
    padding: spacing.md,
    marginTop: spacing.xs,
    marginBottom: spacing.xs,
  },
  mapPinBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.sm,
  },
  mapPinIcon: {
    fontSize: 24,
  },
  mapPinArea: {
    fontSize: 14,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  mapPinPincode: {
    fontSize: 12,
    color: colors.textMuted,
  },
  mapCoordsPill: {
    backgroundColor: '#e2e8f0',
    borderRadius: radius.sm,
    paddingVertical: 4,
    paddingHorizontal: 8,
    marginTop: 8,
    alignSelf: 'flex-start',
  },
  mapCoordsText: {
    fontSize: 11,
    color: colors.textSecondary,
    fontWeight: '600',
  },
  confirmLocationBtn: {
    flex: 1,
    padding: spacing.md,
    borderRadius: radius.md,
    backgroundColor: colors.statusGreen,
    alignItems: 'center',
  },
  confirmLocationBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 13,
  },
  referralCard: {
    borderLeftWidth: 4,
    borderLeftColor: '#10b981',
    backgroundColor: '#f8fafc',
  },
  referralHeaderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: spacing.md,
    marginBottom: spacing.sm,
  },
  referralIconCircle: {
    width: 44,
    height: 44,
    borderRadius: 22,
    backgroundColor: '#ecfdf5',
    justifyContent: 'center',
    alignItems: 'center',
    borderWidth: 1,
    borderColor: '#a7f3d0',
  },
  referralOfferBanner: {
    backgroundColor: '#ecfdf5',
    borderWidth: 1,
    borderColor: '#a7f3d0',
    borderRadius: radius.md,
    padding: spacing.md,
    marginVertical: spacing.sm,
  },
  referralOfferBannerTitle: {
    fontSize: 14,
    fontWeight: '800',
    color: '#065f46',
  },
  referralOfferBannerSub: {
    fontSize: 12,
    color: '#047857',
    marginTop: 3,
    lineHeight: 16,
  },
  referralCodeBox: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#f1f5f9',
    borderRadius: radius.md,
    borderWidth: 1.5,
    borderColor: '#cbd5e1',
    borderStyle: 'dashed',
    paddingHorizontal: spacing.md,
    paddingVertical: spacing.sm,
    justifyContent: 'space-between',
    marginBottom: spacing.md,
  },
  referralCodeText: {
    fontSize: 18,
    fontWeight: '800',
    fontFamily: 'monospace',
    color: '#1e293b',
    letterSpacing: 1.5,
  },
  copyCodeBtn: {
    backgroundColor: colors.primary,
    paddingHorizontal: spacing.md,
    paddingVertical: 6,
    borderRadius: radius.sm,
  },
  copyCodeBtnText: {
    color: colors.surface,
    fontSize: 12,
    fontWeight: '700',
  },
  referralActionsRow: {
    flexDirection: 'row',
    gap: spacing.sm,
    marginBottom: spacing.sm,
  },
  shareInviteBtn: {
    flex: 1,
    backgroundColor: '#10b981',
    paddingVertical: 11,
    borderRadius: radius.md,
    alignItems: 'center',
  },
  shareInviteBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 13,
  },
  directReferBtn: {
    flex: 1,
    backgroundColor: colors.primary,
    paddingVertical: 11,
    borderRadius: radius.md,
    alignItems: 'center',
  },
  directReferBtnText: {
    color: colors.surface,
    fontWeight: '700',
    fontSize: 13,
  },
  historyToggleRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingVertical: spacing.sm,
    marginTop: spacing.xs,
    borderTopWidth: 1,
    borderTopColor: '#e2e8f0',
  },
  historyToggleText: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  historyToggleArrow: {
    fontSize: 12,
    color: colors.primary,
    fontWeight: '600',
  },
  historyContentWrap: {
    marginTop: spacing.xs,
  },
  emptyHistoryBox: {
    padding: spacing.md,
    backgroundColor: '#ffffff',
    borderRadius: radius.md,
    alignItems: 'center',
  },
  emptyHistoryText: {
    fontSize: 12,
    color: colors.textMuted,
    textAlign: 'center',
    lineHeight: 17,
  },
  historyCardRow: {
    flexDirection: 'row',
    alignItems: 'center',
    backgroundColor: '#ffffff',
    padding: spacing.sm,
    borderRadius: radius.md,
    marginBottom: spacing.xs,
    borderWidth: 1,
    borderColor: '#e2e8f0',
  },
  historyRefereeName: {
    fontSize: 13,
    fontWeight: '700',
    color: colors.textPrimary,
  },
  historyRefereePhone: {
    fontSize: 11,
    color: colors.textSecondary,
    marginTop: 2,
  },
  historyDate: {
    fontSize: 10,
    color: colors.textMuted,
    marginTop: 2,
  },
  historyStatusPill: {
    fontSize: 10,
    fontWeight: '800',
    paddingHorizontal: 8,
    paddingVertical: 2,
    borderRadius: radius.sm,
    overflow: 'hidden',
  },
  statusPillRewarded: {
    backgroundColor: '#dcfce7',
    color: '#15803d',
  },
  statusPillQualified: {
    backgroundColor: '#dbeafe',
    color: '#1d4ed8',
  },
  statusPillPending: {
    backgroundColor: '#fef3c7',
    color: '#b45309',
  },
  historyRewardAmount: {
    fontSize: 12,
    fontWeight: '800',
    color: '#059669',
    marginTop: 3,
  },
  directOfferNote: {
    backgroundColor: '#eff6ff',
    padding: spacing.sm,
    borderRadius: radius.sm,
    marginVertical: spacing.sm,
    borderWidth: 1,
    borderColor: '#bfdbfe',
  },
  directOfferNoteText: {
    fontSize: 12,
    color: '#1e40af',
    lineHeight: 16,
  },
});
