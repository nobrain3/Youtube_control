# YouTube Edu Controller

A Flutter application for YouTube educational content management with AI-powered features.

## Security Setup ⚠️

**IMPORTANT: Before running this app, you must configure API keys securely.**

### 1. Environment Variables Setup

1. Copy the example environment file:
   ```bash
   cp .env.example .env
   ```

2. Edit `.env` file with your actual API keys:
   ```env
   # YouTube API Configuration
   YOUTUBE_API_KEY=your_actual_youtube_api_key_here

   # OpenAI API Configuration
   OPENAI_API_KEY=your_actual_openai_api_key_here
   ```

### 2. Getting YouTube API Key

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create or select a project
3. Enable "YouTube Data API v3"
4. Go to "APIs & Services" > "Credentials"
5. Create "API Key"
6. (Optional) Restrict the key to your app and YouTube Data API v3

### 3. Security Notes

- ✅ `.env` file is already in `.gitignore` - API keys will NOT be committed
- ✅ Use `.env.example` as template (contains safe placeholder values)
- ⚠️ Never commit real API keys to version control
- ⚠️ Regularly rotate your API keys for security

## Getting Started

### Prerequisites
- Flutter SDK
- Valid YouTube API key
- Valid OpenAI API key (optional)

### Installation

1. Clone the repository
2. Copy and configure `.env` file (see Security Setup above)
3. Install dependencies:
   ```bash
   flutter pub get
   ```
4. Run the app:
   ```bash
   flutter run
   ```

## Features

- YouTube video search and playback
- AI-powered question generation
- Educational content management
- User authentication with Google
- Personalized recommendations

## API Rate Limits

- YouTube Data API v3: 10,000 requests per day (default)
- Monitor usage in Google Cloud Console

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/).
