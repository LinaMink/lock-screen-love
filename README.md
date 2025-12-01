# 🔐 Lock Screen Love Widget

❤️ Flutter aplikacija su dieninėmis meilės žinutėmis ir lock screen widget'ais poroms.

## ✨ Features
- 📱 **Lock Screen Widgets** - žinutės tiesiai ant užraktinio ekrano
- 👫 **Porų valdymas** - žmona rašo, vyras skaito
- 💌 **Custom žinutės** - kiekvienai dienai individuali žinutė
- 🔄 **Real-time sync** - Firebase automatinė sinchronizacija
- 📅 **365 dienų** - žinutė kiekvienai metų dienai

## 🛠️ Tech Stack
- **Flutter 3.19** - cross-platform framework
- **Firebase** - authentication & Firestore database
- **SharedPreferences** - local storage
- **HomeWidget** - iOS/Android widgets
- **Firebase Auth** - anonymous login

## 🏗️ Project Structure
lib/
├── main.dart # Pagrindinis app
├── screens/
│ └── custom_messages_screen.dart
├── services/
│ ├── firebase_service.dart # Firebase konfigūracija
│ ├── couple_service.dart # Porų logika
│ ├── message_service.dart # Žinučių valdymas
│ └── user_service.dart # Vartotojo sesija
├── data/
│ ├── messages.dart # Default žinutės
│ └── custom_messages.dart # Custom žinutės
└── widgets/ # Custom widgets



## 🚀 Getting Started

### Prerequisites
- Flutter 3.0+
- Android Studio / Xcode
- Firebase account

### Installation
```bash
# Clone repository
git clone https://github.com/LinaMink/lock-screen-love.git

# Install dependencies
flutter pub get

# Run on device
flutter run
