# KeepAnEye - Child Care Coordination App

A secure iOS app that allows parents and caregivers to coordinate child care with real-time updates, schedule tracking, and secure data sharing.

## Features

- **Medicine Schedule Tracking**: Manage and track child's medication schedule
- **Feeding Schedule**: Track eating and milk schedules
- **Shared Feed**: Post notes, photos, and videos with commenting
- **Profile Management**: Parent-controlled caregiver access
- **Real-time Sync**: Secure data sharing between devices
- **Offline Support**: Local data storage with sync when online

## Security Features

- End-to-end encryption
- Temporary server storage (auto-deleted after sync)
- Biometric authentication
- Local data persistence
- Secure device pairing

## Tech Stack

### iOS App
- **SwiftUI** - Modern iOS UI framework
- **Core Data** - Local data persistence
- **Firebase** - Push notifications
- **Combine** - Reactive programming

### Backend
- **Node.js** - Server runtime
- **Express.js** - Web framework
- **TypeScript** - Type safety
- **PostgreSQL** - Database
- **JWT** - Authentication

## Project Structure

```
keepaneye/
├── ios-app/           # SwiftUI iOS application
├── backend/           # Node.js backend API
├── docs/             # Documentation
└── README.md         # This file
```

## Getting Started

### Prerequisites
- Xcode 14+ (for iOS development)
- Node.js 18+ (for backend)
- PostgreSQL 13+
- Firebase account

### Installation

1. **Backend Setup**
   ```bash
   cd backend
   npm install
   npm run dev
   ```

2. **iOS App Setup**
   - Open `ios-app/KeepAnEye.xcodeproj` in Xcode
   - Configure Firebase in your project
   - Build and run on device/simulator

## Development Status

🚧 **In Development** - Core infrastructure and basic features being implemented

## License

Private - All rights reserved 