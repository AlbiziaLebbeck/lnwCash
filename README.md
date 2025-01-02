# LnwCash  

LnwCash is a simple and fast **Ecash wallet** designed for both Progressive Web App (PWA) and Android platforms. It leverages **Nostr** and **Cashu protocols** to enable simple, private, and secure Bitcoin microtransactions.  

## Features  

- **Encrypted Wallet Storage**: Secure your wallet with encryption and store it on Nostr relays using NIP-60.  
- **Cashu Integration**: Send and receive cCash tokens.
- **Bitcoin Lightning** Enable fast Bitcoin payments via the Lightning Network.  
- **Mint Management**: Manage tokens across multiple mints independently.  
- **Theming Options**: Customize your wallet interface with light and dark modes, and select colors to match your style.  

## Tagline  

*Take Control of Your Satoshi with Ecash.*  

## Prerequisites  

- **Flutter SDK**: Install [Flutter](https://flutter.dev/) (v3.5.0 or later).  
- **Dart SDK**: Ensure Dart is included with Flutter.  
- **Android Studio**: For running on Android devices.  
- **Browser**: For PWA testing and deployment.  

## Getting Started  

### 1. Clone the Repository  

```bash  
git https://github.com/AlbiziaLebbeck/lnwCash.git
cd lnwCash
```

### 2. Install Dependencies

Run the following command to fetch the required packages:

```bash
flutter pub get  
```

### 3. Run the Application

**For PWA**

```bash
flutter run -d chrome  
```
 
**For Android**

Connect your Android device or emulator and run:

```bash
flutter run  
```

## Deployment

**PWA Deployment**

1. Build the web version of the app:

```bash
flutter build web  
```

2. Deploy the build/web directory to your web server or hosting platform (e.g., Firebase Hosting, Vercel).

**Android APK**

Generate an APK for manual installation or Play Store deployment:

```bash
flutter build apk --release
```

<!-- ---

## License

LnwCash is an open-source project licensed under the MIT License. -->

---

## Screenshots


---

## Acknowledgments  

LnwCash is built using:  
- [Flutter](https://flutter.dev/)  
- [Dart](https://dart.dev/)  
- [Nostr Protocol](https://github.com/nostr-protocol) with **NIP-60** for encrypted wallet storage and secure token transfer.  
- [Cashu Protocol](https://cashu.dev/)  
