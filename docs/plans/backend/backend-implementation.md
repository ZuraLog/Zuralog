# Backend Implementation Plan (Phase 1)

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build the robust, testable logic layer for Life Logger — the "Cloud Brain" and "Edge Agent" that connect Apple HealthKit, Google Health Connect, Strava, and CalAI into a unified AI health assistant.

**Philosophy:** "Logic before Pixels." We build a functional system first, visual polish second. The MVP is complete ONLY when Phase 1 is 100% verified with a working test harness, AND Phase 2 (Frontend) is finished.

**Architecture:** Hybrid Hub — Python/FastAPI Cloud Brain + Flutter Edge Agent. All integrations via MCP (Model Context Protocol).

**Tech Stack:**
- Cloud Brain: Python, FastAPI, PostgreSQL (Supabase), Pinecone, Celery, Redis
- Edge Agent: Dart, Flutter, Riverpod, Dio, Drift, Platform Channels
- Integrations: MCP Servers for Strava, HealthKit, Health Connect

---

## Phase 1.1: Foundation & Infrastructure

> **Reference:** Review `../architecture-design.md` Section 2.3 for Cloud Brain directory structure.

**Goal:** Establish the development environment, repository structure, and core infrastructure for both Cloud Brain and Edge Agent.

**Depends On:** None  
**Estimated Duration:** 3-4 days

### 1.1.1 Cloud Brain Repository Setup

**Files:**
- Create: `cloud-brain/pyproject.toml`
- Create: `cloud-brain/Dockerfile`
- Create: `cloud-brain/docker-compose.yml`
- Create: `cloud-brain/app/main.py`
- Create: `cloud-brain/app/config.py`

**Steps:**

1. **Create Cloud Brain project structure**

```bash
mkdir -p cloud-brain
cd cloud-brain
poetry init --name life-logger-cloud-brain
poetry add fastapi uvicorn sqlalchemy asyncpg pydantic pydantic-settings python-dotenv openai pinecone celery redis httpx
poetry add --group dev pytest pytest-asyncio black ruff
```

2. **Create `cloud-brain/app/config.py`**

```python
from pydantic_settings import BaseSettings

class Settings(BaseSettings):
    supabase_url: str
    supabase_anon_key: str
    supabase_service_key: str
    openrouter_api_key: str
    openrouter_referer: str = "https://lifelogger.app"
    openrouter_title: str = "Life Logger"
    pinecone_api_key: str
    redis_url: str
    strava_client_id: str
    strava_client_secret: str
    
    class Config:
        env_file = ".env"

settings = Settings()
```

3. **Create `cloud-brain/app/main.py`**

```python
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

app = FastAPI(title="Life Logger Cloud Brain")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.get("/health")
async def health_check():
    return {"status": "healthy"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
```

4. **Test the setup**

```bash
cd cloud-brain
poetry run uvicorn app.main:app --reload
# Verify: http://localhost:8000/health returns {"status": "healthy"}
```

**Exit Criteria:** Cloud Brain starts without errors, health endpoint returns 200.

---

### 1.1.2 Database Setup (Supabase)

**Files:**
- Create: `cloud-brain/app/models/__init__.py`
- Create: `cloud-brain/app/models/user.py`
- Create: `cloud-brain/app/models/integration.py`
- Create: `cloud-brain/alembic.ini`
- Create: `cloud-brain/alembic/env.py`

**Steps:**

1. **Create SQLAlchemy async engine in `cloud-brain/app/database.py`**

```python
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.declarative import declarative_base

DATABASE_URL = f"postgresql+asyncpg://..."

engine = create_async_engine(DATABASE_URL, echo=True)
async_session = sessionmaker(engine, class_=AsyncSession, expire_on_commit=False)
Base = declarative_base()

async def get_db():
    async with async_session() as session:
        yield session
```

2. **Create User model in `cloud-brain/app/models/user.py`**

```python
from sqlalchemy import Column, String, DateTime, Boolean
from sqlalchemy.sql import func
from cloudbrain.app.database import Base

class User(Base):
    __tablename__ = "users"
    
    id = Column(String, primary_key=True)  # Supabase UID
    email = Column(String, unique=True, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    coach_persona = Column(String, default="tough_love")  # gentle, balanced, tough_love
    is_premium = Column(Boolean, default=False)
```

3. **Create Integration model in `cloud-brain/app/models/integration.py`**

```python
from sqlalchemy import Column, String, DateTime, Boolean, JSON
from cloudbrain.app.database import Base

class Integration(Base):
    __tablename__ = "integrations"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, index=True)  # FK to users.id
    provider = Column(String)  # strava, apple_health, health_connect, fitbit, oura
    access_token = Column(String)
    refresh_token = Column(String)
    token_expires_at = Column(DateTime(timezone=True))
    metadata = Column(JSON)  # Store provider-specific data
    is_active = Column(Boolean, default=True)
    last_synced_at = Column(DateTime(timezone=True))
```

4. **Run migrations**

```bash
cd cloud-brain
poetry run alembic init alembic
poetry run alembic revision --autogenerate -m "initial tables"
poetry run alembic upgrade head
```

**Exit Criteria:** Database tables created, migrations run successfully.

---

### 1.1.3 Edge Agent (Flutter) Project Setup

**Files:**
- Create: `life_logger/pubspec.yaml`
- Create: `life_logger/lib/main.dart`
- Create: `life_logger/lib/app.dart`
- Create: `life_logger/lib/core/di/providers.dart`

**Steps:**

1. **Initialize Flutter project**

```bash
flutter create life_logger --org com.lifelogger --platforms ios,android
cd life_logger
```

2. **Configure `pubspec.yaml` with dependencies**

```yaml
dependencies:
  flutter:
    sdk: flutter
  flutter_riverpod: ^2.4.0
  riverpod_annotation: ^2.3.0
  dio: ^5.3.0
  go_router: ^12.0.0
  drift: ^2.14.0
  sqlite3_flutter_libs: ^0.5.18
  flutter_secure_storage: ^9.0.0
  web_socket_channel: ^2.4.0
  url_launcher: ^6.2.0
  firebase_core: ^2.24.0
  firebase_messaging: ^14.7.0
  
dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.0
  build_runner: ^2.4.0
  riverpod_generator: ^2.3.0
```

3. **Create basic app shell in `life_logger/lib/main.dart`**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const ProviderScope(
      child: LifeLoggerApp(),
    ),
  );
}
```

4. **Create minimal `app.dart`**

```dart
import 'package:flutter/material.dart';

class LifeLoggerApp extends StatelessWidget {
  const LifeLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Life Logger',
      home: const Scaffold(
        body: Center(child: Text('Life Logger - Test Harness')),
      ),
    );
  }
}
```

5. **Build to verify**

```bash
cd life_logger
flutter build ios --simulator --no-codesign
flutter build apk --debug
```

**Exit Criteria:** Flutter app builds successfully for iOS simulator and Android APK.

---

### 1.1.4 Edge Agent Network Layer

**Files:**
- Create: `life_logger/lib/core/network/api_client.dart`
- Create: `life_logger/lib/core/network/ws_client.dart`
- Create: `life_logger/lib/core/network/fcm_service.dart`

**Steps:**

1. **Create API client in `life_logger/lib/core/network/api_client.dart`**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ApiClient {
  final Dio _dio;
  final FlutterSecureStorage _storage;
  
  ApiClient({Dio? dio, FlutterSecureStorage? storage})
      : _dio = dio ?? Dio(),
        _storage = storage ?? const FlutterSecureStorage() {
    _dio.options.baseUrl = 'http://10.0.2.2:8000'; // Android emulator
    _dio.options.connectTimeout = const Duration(seconds: 30);
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.read(key: 'auth_token');
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        return handler.next(options);
      },
    ));
  }
  
  Future<Response> get(String path) => _dio.get(path);
  Future<Response> post(String path, {dynamic data}) => _dio.post(path, data: data);
}
```

2. **Create WebSocket client in `life_logger/lib/core/network/ws_client.dart`**

```dart
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';

class WsClient {
  WebSocketChannel? _channel;
  final String _baseUrl;
  
  WsClient({String? baseUrl}) : _baseUrl = baseUrl ?? 'ws://10.0.2.2:8000';
  
  void connect(String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('$_baseUrl/ws/chat?token=$token'),
    );
  }
  
  Stream<dynamic> get stream => _channel!.stream;
  
  void send(String message) {
    _channel?.sink.add(jsonEncode({'message': message}));
  }
  
  void disconnect() {
    _channel?.sink.close();
  }
}
```

3. **Verify imports work**

```bash
cd life_logger
flutter analyze
```

**Exit Criteria:** No analysis errors, network layer compiles.

---

### 1.1.5 Edge Agent Local Storage

**Files:**
- Create: `life_logger/lib/core/storage/secure_storage.dart`
- Create: `life_logger/lib/core/storage/local_db.dart`

**Steps:**

1. **Create secure storage wrapper**

```dart
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SecureStorage {
  final FlutterSecureStorage _storage;
  
  SecureStorage({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();
  
  Future<void> write(String key, String value) => _storage.write(key: key, value: value);
  Future<String?> read(String key) => _storage.read(key: key);
  Future<void> delete(String key) => _storage.delete(key: key);
  
  // Auth tokens
  Future<void> saveAuthToken(String token) => write('auth_token', token);
  Future<String?> getAuthToken() => read('auth_token');
  Future<void> clearAuthToken() => delete('auth_token');
  
  // Integration tokens
  Future<void> saveIntegrationToken(String provider, String token) =>
      write('integration_$provider', token);
  Future<String?> getIntegrationToken(String provider) =>
      read('integration_$provider');
}
```

2. **Create local DB (Drift) for offline caching**

```dart
// lib/core/storage/local_db.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';

part 'local_db.g.dart';

class Messages extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get content => text()();
  TextColumn get role => text()(); // 'user' or 'assistant'
  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [Messages])
class LocalDb extends _$LocalDb {
  LocalDb() : super(NativeDatabase(File('local.db')));
  
  @override
  int get schemaVersion => 1;
  
  Future<List<Message>> getAllMessages() => select(messages).get();
  Future<int> insertMessage(MessagesCompanion msg) => into(messages).insert(msg);
}
```

3. **Run build_runner for Drift**

```bash
cd life_logger
flutter pub run build_runner build
```

**Exit Criteria:** Secure storage and local DB compile successfully.

---

### 1.1.6 Developer UI Harness (No Styling)

**Files:**
- Modify: `life_logger/lib/app.dart`
- Create: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Create basic test harness screen**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HarnessScreen extends ConsumerStatefulWidget {
  const HarnessScreen({super.key});

  @override
  ConsumerState<HarnessScreen> createState() => _HarnessScreenState();
}

class _HarnessScreenState extends ConsumerState<HarnessScreen> {
  final _outputController = TextEditingController();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TEST HARNESS - NO STYLING')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text('COMMANDS:'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ElevatedButton(
                  onPressed: () => _outputController.text = 'Login test...',
                  child: const Text('1. Login'),
                ),
                ElevatedButton(
                  onPressed: () => _outputController.text = 'Strava connect...',
                  child: const Text('2. Connect Strava'),
                ),
                ElevatedButton(
                  onPressed: () => _outputController.text = 'Fetch activities...',
                  child: const Text('3. Fetch Runs'),
                ),
                ElevatedButton(
                  onPressed: () => _outputController.text = 'Health read...',
                  child: const Text('4. Read HealthKit'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('OUTPUT:'),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _outputController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Output will appear here...',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

2. **Update app.dart to show harness**

```dart
import 'features/harness/harness_screen.dart';

class LifeLoggerApp extends StatelessWidget {
  const LifeLoggerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const HarnessScreen(),
    );
  }
}
```

**Exit Criteria:** App builds and shows raw test harness UI with buttons and text output area.

---

**Phase 1.1 Exit Criteria:**
- [ ] Cloud Brain starts with health endpoint
- [ ] Database tables created (users, integrations)
- [ ] Flutter app builds for iOS and Android
- [ ] Network layer compiles (API client, WebSocket)
- [ ] Local storage compiles (secure storage, Drift)
- [ ] Test harness screen renders with buttons

---

## Phase 1.2: Authentication & User Management

> **Reference:** Review `../architecture-design.md` Section 2.3 for Cloud Brain API routes.

**Goal:** Implement user authentication flow — signup, login, logout — using Supabase Auth.

**Depends On:** Phase 1.1 (Foundation)  
**Estimated Duration:** 3 days

### 1.2.1 Cloud Brain Auth Endpoints

**Files:**
- Create: `cloud-brain/app/api/v1/auth.py`
- Modify: `cloud-brain/app/main.py`

**Steps:**

1. **Create auth router in `cloud-brain/app/api/v1/auth.py`**

```python
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from supabase import create_client, Client

router = APIRouter(prefix="/auth", tags=["auth"])
security = HTTPBearer()

# Initialize Supabase client (use settings.supabase_url, settings.supabase_anon_key)
supabase: Client = None  # Initialize in main.py and inject

class LoginRequest(BaseModel):
    email: str
    password: str

class RegisterRequest(BaseModel):
    email: str
    password: str

@router.post("/register")
async def register(request: RegisterRequest):
    """User registration via Supabase Auth."""
    try:
        auth_response = supabase.auth.sign_up(email=request.email, password=request.password)
        return {"user_id": auth_response.user.id, "session": auth_response.session}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))

@router.post("/login")
async def login(request: LoginRequest):
    """User login via Supabase Auth."""
    try:
        auth_response = supabase.auth.sign_in(email=request.email, password=request.password)
        return {"user_id": auth_response.user.id, "session": auth_response.session}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

@router.post("/logout")
async def logout(credentials: HTTPAuthorizationCredentials = Depends(security)):
    """User logout."""
    try:
        supabase.auth.sign_out()
        return {"message": "Logged out successfully"}
    except Exception as e:
        raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(e))
```

2. **Wire up router in main.py**

```python
from cloudbrain.app.api.v1 import auth

app.include_router(auth.router)
```

3. **Test with curl**

```bash
# Test registration
curl -X POST http://localhost:8000/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}'

# Test login
curl -X POST http://localhost:8000/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"test@example.com","password":"testpass123"}'
```

**Exit Criteria:** Registration and login endpoints return valid session tokens.

---

### 1.2.2 User Sync to Local Database

**Files:**
- Modify: `cloud-brain/app/api/v1/auth.py`
- Create: `cloud-brain/app/services/user_service.py`

**Steps:**

1. **Create user sync service**

```python
# cloud-brain/app/services/user_service.py
from sqlalchemy.ext.asyncio import AsyncSession
from cloudbrain.app.models.user import User

async def sync_user_to_db(db: AsyncSession, supabase_user_id: str, email: str):
    """Ensure user exists in our users table after auth."""
    from sqlalchemy import select
    
    result = await db.execute(
        select(User).where(User.id == supabase_user_id)
    )
    existing_user = result.scalar_one_or_none()
    
    if not existing_user:
        new_user = User(id=supabase_user_id, email=email)
        db.add(new_user)
        await db.commit()
        return new_user
    
    return existing_user
```

2. **Call sync in register/login endpoints**

```python
@router.post("/register")
async def register(request: RegisterRequest, db: AsyncSession = Depends(get_db)):
    auth_response = supabase.auth.sign_up(email=request.email, password=request.password)
    await sync_user_to_db(db, auth_response.user.id, request.email)
    return {"user_id": auth_response.user.id}
```

**Exit Criteria:** New users are created in Supabase Auth AND in our local `users` table.

---

### 1.2.3 Edge Agent Auth Repository

**Files:**
- Create: `life_logger/lib/features/auth/data/auth_repository.dart`
- Create: `life_logger/lib/features/auth/domain/auth_service.dart`

**Steps:**

1. **Create auth repository**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  
  AuthRepository({required ApiClient apiClient, required SecureStorage secureStorage})
      : _apiClient = apiClient,
        _secureStorage = secureStorage;
  
  Future<bool> login(String email, String password) async {
    try {
      final response = await _apiClient.post('/auth/login', data: {
        'email': email,
        'password': password,
      });
      
      final session = response.data['session'];
      await _secureStorage.saveAuthToken(session['access_token']);
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<bool> register(String email, String password) async {
    try {
      final response = await _apiClient.post('/auth/register', data: {
        'email': email,
        'password': password,
      });
      return true;
    } catch (e) {
      return false;
    }
  }
  
  Future<void> logout() async {
    await _apiClient.post('/auth/logout');
    await _secureStorage.clearAuthToken();
  }
  
  Future<bool> isLoggedIn() async {
    final token = await _secureStorage.getAuthToken();
    return token != null;
  }
}
```

2. **Create Riverpod provider**

```dart
final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(
    apiClient: ref.watch(apiClientProvider),
    secureStorage: ref.watch(secureStorageProvider),
  );
});

final isLoggedInProvider = FutureProvider<bool>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.isLoggedIn();
});
```

**Exit Criteria:** Auth repository compiles, login/logout methods defined.

---

### 1.2.4 Edge Agent Auth UI in Harness

**Files:**
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Add login UI to harness**

```dart
class _HarnessScreenState extends ConsumerState<HarnessScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _outputController = TextEditingController();
  bool _isLoggedIn = false;
  
  void _handleLogin() async {
    final authRepo = ref.read(authRepositoryProvider);
    final success = await authRepo.login(
      _emailController.text,
      _passwordController.text,
    );
    
    setState(() {
      _isLoggedIn = success;
      _outputController.text = success 
          ? 'LOGIN SUCCESS: Token saved'
          : 'LOGIN FAILED: Check credentials';
    });
  }
  
  // In the widget tree, add TextFields and Login button:
  // TextField(controller: _emailController, decoration: InputDecoration(labelText: 'Email'))
  // TextField(controller: _passwordController, decoration: InputDecoration(labelText: 'Password'))
  // ElevatedButton(onPressed: _handleLogin, child: Text('Login'))
```

**Exit Criteria:** Login button in harness triggers auth, prints result to output area.

---

### 1.2.5 Token Refresh Logic

**Files:**
- Modify: `life_logger/lib/core/network/api_client.dart`

**Steps:**

1. **Add token refresh interceptor**

```dart
_interceptors.add(InterceptorsWrapper(
  onError: (error, handler) async {
    if (error.response?.statusCode == 401) {
      // Try to refresh token
      final refreshToken = await _storage.read(key: 'refresh_token');
      if (refreshToken != null) {
        try {
          final response = await _dio.post('/auth/refresh', data: {
            'refresh_token': refreshToken,
          });
          final newToken = response.data['access_token'];
          await _storage.write(key: 'auth_token', value: newToken);
          
          // Retry original request
          error.requestOptions.headers['Authorization'] = 'Bearer $newToken';
          final retryResponse = await _dio.fetch(error.requestOptions);
          return handler.resolve(retryResponse);
        } catch (e) {
          await _storage.clear();
        }
      }
    }
    return handler.next(error);
  },
));
```

**Exit Criteria:** Token refresh logic compiles and is part of the interceptor chain.

---

**Phase 1.2 Exit Criteria:**
- [ ] Cloud Brain auth endpoints work (register, login, logout)
- [ ] Users sync to local database after auth
- [ ] Edge Agent auth repository implemented
- [ ] Harness shows login UI, accepts credentials, prints result
- [ ] Token refresh logic is in place

---

## Phase 1.3: MCP Base Framework

> **Reference:** Review `../architecture-design.md` Section 2.4 for MCP Architecture.

**Goal:** Build the foundation for all external integrations using the Model Context Protocol (MCP).

**Depends On:** Phase 1.2 (Auth)  
**Estimated Duration:** 4-5 days

### 1.3.1 MCP Server Base Class

**Files:**
- Create: `cloud-brain/app/mcp_servers/base_server.py`
- Create: `cloud-brain/app/mcp_servers/__init__.py`

**Steps:**

1. **Create base MCP server class**

```python
from abc import ABC, abstractmethod
from typing import Any

class BaseMCPServer(ABC):
    """Abstract MCP server interface."""
    
    @property
    @abstractmethod
    def name(self) -> str:
        """Server name for identification."""
        pass
    
    @property
    @abstractmethod
    def description(self) -> str:
        """Server description for tool schema."""
        pass
    
    @abstractmethod
    def get_tools(self) -> list[dict]:
        """
        Return tool schemas the LLM can call.
        Format: [
            {
                "name": "tool_name",
                "description": "What this tool does",
                "input_schema": {
                    "type": "object",
                    "properties": {...},
                    "required": [...]
                }
            }
        ]
        """
        pass
    
    @abstractmethod
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        """
        Execute a tool call and return structured results.
        
        Args:
            tool_name: Name of the tool to execute
            params: Parameters for the tool
            user_id: The user making the request
            
        Returns:
            dict with 'success', 'data', and optionally 'error' keys
        """
        pass
    
    @abstractmethod
    async def get_resources(self, user_id: str) -> list[dict]:
        """
        Return available data resources (e.g., recent activities).
        """
        pass
```

2. **Create tool result model**

```python
# cloud-brain/app/mcp_servers/models.py
from pydantic import BaseModel

class ToolResult(BaseModel):
    success: bool
    data: Any = None
    error: str | None = None
    
    class Config:
        arbitrary_types_allowed = True
```

**Exit Criteria:** Base class defined, other servers can inherit from it.

---

### 1.3.2 MCP Client (Orchestrator)

**Files:**
- Create: `cloud-brain/app/agent/mcp_client.py`
- Create: `cloud-brain/app/agent/orchestrator.py`

**Steps:**

1. **Create MCP client**

```python
from typing import Any
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer

class MCPClient:
    """Routes tool calls to the appropriate MCP server."""
    
    def __init__(self):
        self._servers: dict[str, BaseMCPServer] = {}
    
    def register_server(self, server: BaseMCPServer):
        """Register an MCP server."""
        self._servers[server.name] = server
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        """Execute a tool across all registered servers."""
        # Find which server has this tool
        for server in self._servers.values():
            tools = server.get_tools()
            tool_names = [t['name'] for t in tools]
            
            if tool_name in tool_names:
                return await server.execute_tool(tool_name, params, user_id)
        
        return {"success": False, "error": f"Tool {tool_name} not found"}
    
    def get_all_tools(self) -> list[dict]:
        """Get consolidated tool list from all servers."""
        tools = []
        for server in self._servers.values():
            tools.extend(server.get_tools())
        return tools
```

2. **Create orchestrator**

```python
# cloud-brain/app/agent/orchestrator.py
from cloudbrain.app.agent.mcp_client import MCPClient
from cloudbrain.app.agent.context_manager import ContextManager

class Orchestrator:
    """LLM Agent that orchestrates MCP tool calls."""
    
    def __init__(self, mcp_client: MCPClient, context_manager: ContextManager):
        self.mcp_client = mcp_client
        self.context_manager = context_manager
    
    async def process_message(self, user_id: str, message: str) -> str:
        """
        Process user message and return AI response.
        This is a simplified version - full version uses OpenAI function calling.
        """
        # 1. Get user context from Pinecone
        context = await self.context_manager.get_context(user_id)
        
        # 2. Get available tools
        tools = self.mcp_client.get_all_tools()
        
        # 3. In MVP, we use a simple prompt to determine if tools are needed
        # Full version: OpenAI function calling to select tools
        response = f"Processing: {message}"
        
        return response
```

**Exit Criteria:** MCP client can route tool calls to registered servers.

---

### 1.3.3 Tool Schema Definitions

**Files:**
- Create: `cloud-brain/app/agent/prompts/tools_schema.py`

**Steps:**

1. **Create consolidated tools schema**

```python
# This file consolidates all MCP tool definitions for the LLM

TOOLS_SCHEMA = """
# Available Tools

## Strava
- get_activities: Get recent activities from Strava
  params: user_id, limit (optional), start_date (optional)
- create_activity: Create a manual activity in Strava
  params: user_id, name, sport_type, distance, elapsed_time, start_date_local
- get_athlete_stats: Get athlete statistics from Strava
  params: user_id

## Apple Health
- read_health_metrics: Read health data from Apple HealthKit
  params: user_id, data_type (steps|calories|heart_rate|sleep|workouts), start_date, end_date
- write_health_entry: Write health data to Apple HealthKit
  params: user_id, data_type, value, date

## Google Health Connect
- read_health_connect: Read health data from Google Health Connect
  params: user_id, data_type, start_date, end_date
- write_health_connect: Write health data to Google Health Connect
  params: user_id, data_type, value, date

## Deep Links
- open_app: Open an external app via deep link
  params: app (strava|calai|myfitnesspal), action (record|camera)
"""
```

**Exit Criteria:** Tools schema defined and imported by orchestrator.

---

### 1.3.4 Context Manager (Pinecone Integration)

**Files:**
- Create: `cloud-brain/app/agent/context_manager/memory_manager.py`
- Create: `cloud-brain/app/agent/context_manager/user_profile.py`

**Steps:**

1. **Create Pinecone client wrapper**

```python
from pinecone import Pinecone
from cloudbrain.app.config import settings

class MemoryManager:
    """Manages long-term user context via Pinecone."""
    
    def __init__(self):
        self._client = Pinecone(api_key=settings.pinecone_api_key)
        self._index = self._client.Index("life-logger-context")
    
    async def add_context(self, user_id: str, text: str, metadata: dict):
        """Add a memory to the vector store."""
        # In production, embed text with OpenAI
        # For MVP, we use simple metadata storage
        self._index.upsert(
            vectors=[{
                "id": f"{user_id}_{metadata.get('timestamp')}",
                "values": [0.0] * 1536,  # Placeholder - use embeddings in production
                "metadata": {"user_id": user_id, "text": text, **metadata}
            }]
        )
    
    async def get_context(self, user_id: str, query: str = "", limit: int = 5) -> list[dict]:
        """Retrieve relevant context for a user."""
        results = self._index.query(
            vector=[0.0] * 1536,
            filter={"user_id": {"$eq": user_id}},
            top_k=limit,
            include_metadata=True
        )
        return [match['metadata'] for match in results['matches']]
```

2. **Create user profile manager**

```python
class UserProfile:
    """Manages user profile data."""
    
    def __init__(self, db):
        self.db = db
    
    async def get_profile(self, user_id: str) -> dict:
        """Get user profile with preferences."""
        # Query from Supabase
        return {
            "coach_persona": "tough_love",
            "goals": {"weight_loss": True, "weekly_runs": 3},
            "connected_apps": []
        }
```

**Exit Criteria:** Context manager compiles and can connect to Pinecone (or mock).

---

### 1.3.5 MCP Server Registry

**Files:**
- Create: `cloud-brain/app/mcp_servers/registry.py`

**Steps:**

1. **Create server registry**

```python
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer

class MCPServerRegistry:
    """Central registry for all MCP servers."""
    
    def __init__(self):
        self._servers: dict[str, BaseMCPServer] = {}
    
    def register(self, server: BaseMCPServer):
        self._servers[server.name] = server
    
    def get(self, name: str) -> BaseMCPServer | None:
        return self._servers.get(name)
    
    def list_all(self) -> list[BaseMCPServer]:
        return list(self._servers.values())

# Global registry instance
registry = MCPServerRegistry()
```

**Exit Criteria:** Registry created, can hold multiple server instances.

---

### 1.3.6 MCP Integration Tests

**Files:**
- Create: `cloud-brain/tests/mcp/test_base_server.py`
- Create: `cloud-brain/tests/mcp/test_client.py`

**Steps:**

1. **Write base server test**

```python
import pytest
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer

class MockServer(BaseMCPServer):
    @property
    def name(self) -> str:
        return "mock_server"
    
    @property
    def description(self) -> str:
        return "Mock server for testing"
    
    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "mock_tool",
                "description": "A mock tool",
                "input_schema": {
                    "type": "object",
                    "properties": {"input": {"type": "string"}},
                    "required": ["input"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        return {"success": True, "data": f"Mock executed: {params}"}
    
    async def get_resources(self, user_id: str) -> list[dict]:
        return [{"type": "mock_resource", "data": "test"}]

def test_mock_server_inherits_base():
    server = MockServer()
    assert server.name == "mock_server"
    assert len(server.get_tools()) == 1
```

2. **Run tests**

```bash
cd cloud-brain
poetry run pytest tests/mcp/ -v
```

**Exit Criteria:** All MCP tests pass.

---

**Phase 1.3 Exit Criteria:**
- [ ] Base MCP server class defined
- [ ] MCP client can route tool calls to servers
- [ ] Tool schema defined
- [ ] Context manager (Pinecone) integration in place
- [ ] Server registry created
- [ ] MCP tests pass

---

## Phase 1.4: Apple HealthKit Integration

> **Reference:** See `integrations/apple-health-integration.md` for deep dive on HealthKit API.

**Goal:** Implement read/write access to Apple HealthKit on iOS via Flutter platform channels.

**Depends On:** Phase 1.3 (MCP Base Framework)  
**Estimated Duration:** 5-6 days

### 1.4.1 HealthKit Entitlements & Permissions (iOS)

**Files:**
- Modify: `life_logger/ios/Runner/Runner.entitlements`
- Modify: `life_logger/ios/Runner/Info.plist`

**Steps:**

1. **Enable HealthKit capability**

In Xcode:
- Open `life_logger/ios/Runner.xcworkspace`
- Select Runner target → Signing & Capabilities
- Add HealthKit capability
- Check "Background Modes" → "Background fetch"

2. **Configure entitlements file**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.healthkit</key>
    <true/>
    <key>com.apple.developer.healthkit.access</key>
    <array/>
    <key>com.apple.developer.healthkit.background-delivery</key>
    <true/>
</dict>
</plist>
```

3. **Configure Info.plist**

```xml
<key>NSHealthShareUsageDescription</key>
<string>Life Logger needs access to your health data to provide personalized AI coaching and track your fitness goals.</string>
<key>NSHealthUpdateUsageDescription</key>
<string>Life Logger needs to write health data (like workouts and nutrition) to Apple Health based on your requests.</string>
```

**Exit Criteria:** HealthKit capability enabled, entitlements configured, usage descriptions added.

---

### 1.4.2 Swift HealthKit Bridge

**Files:**
- Create: `life_logger/ios/Runner/HealthKitBridge.swift`

**Steps:**

1. **Create HealthKit bridge**

```swift
import Foundation
import HealthKit

class HealthKitBridge: NSObject {
    private let healthStore = HKHealthStore()
    
    // Data types we need to read/write
    private let readTypes: Set<HKObjectType> = [
        HKObjectType.quantityType(forIdentifier: .stepCount)!,
        HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.workoutType(),
        HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!,
    ]
    
    private let writeTypes: Set<HKSampleType> = [
        HKObjectType.quantityType(forIdentifier: .dietaryEnergyConsumed)!,
        HKObjectType.quantityType(forIdentifier: .bodyMass)!,
        HKObjectType.workoutType(),
    ]
    
    func isAvailable() -> Bool {
        return HKHealthStore.isHealthDataAvailable()
    }
    
    func requestAuthorization(completion: @escaping (Bool, Error?) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, nil)
            return
        }
        
        healthStore.requestAuthorization(toShare: writeTypes, read: readTypes) { success, error in
            completion(success, error)
        }
    }
    
    // MARK: - Read Methods
    
    func fetchSteps(date: Date, completion: @escaping (Double?, Error?) -> Void) {
        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }
        
        let startOfDay = Calendar.current.startOfDay(for: date)
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: date, options: .strictStartDate)
        
        let query = HKStatisticsQuery(
            quantityType: stepType,
            quantitySamplePredicate: predicate,
            options: .cumulativeSum
        ) { _, result, error in
            guard let result = result, let sum = result.sumQuantity() else {
                completion(nil, error)
                return
            }
            let steps = sum.doubleValue(for: HKUnit.count())
            completion(steps, nil)
        }
        
        healthStore.execute(query)
    }
    
    func fetchWorkouts(startDate: Date, endDate: Date, completion: @escaping ([[String: Any]]?, Error?) -> Void) {
        guard let workoutType = HKObjectType.workoutType() else { return }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        
        let query = HKSampleQuery(
            sampleType: workoutType,
            predicate: predicate,
            limit: HKObjectQueryNoLimit,
            sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
        ) { _, samples, error in
            guard let workouts = samples as? [HKWorkout] else {
                completion(nil, error)
                return
            }
            
            let workoutData = workouts.map { workout in
                [
                    "id": workout.uuid.uuidString,
                    "activityType": workout.workoutActivityType.name,
                    "duration": workout.duration,
                    "startDate": workout.startDate.timeIntervalSince1970,
                    "endDate": workout.endDate.timeIntervalSince1970,
                    "energyBurned": workout.totalEnergyBurned?.doubleValue(for: HKUnit.kilocalorie()) ?? 0
                ]
            }
            
            completion(workoutData, nil)
        }
        
        healthStore.execute(query)
    }
    
    // MARK: - Write Methods
    
    func writeWorkout(
        activityType: String,
        startDate: Date,
        endDate: Date,
        energyBurned: Double,
        completion: @escaping (Bool, Error?) -> Void
    ) {
        let workoutType: HKWorkoutActivityType
        switch activityType.lowercased() {
        case "run", "running": workoutType = .running
        case "walk", "walking": workoutType = .walking
        case "cycle", "cycling": workoutType = .cycling
        default: workoutType = .traditionalStrengthTraining
        }
        
        let workout = HKWorkout(
            activityType: workoutType,
            start: startDate,
            end: endDate,
            duration: endDate.timeIntervalSince(startDate),
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: energyBurned),
            totalDistance: nil,
            metadata: nil
        )
        
        healthStore.save(workout) { success, error in
            completion(success, error)
        }
    }
    
    func writeNutrition(calories: Double, date: Date, completion: @escaping (Bool, Error?) -> Void) {
        guard let energyType = HKQuantityType.quantityType(forIdentifier: .dietaryEnergyConsumed) else {
            completion(false, nil)
            return
        }
        
        let quantity = HKQuantity(unit: .kilocalorie(), doubleValue: calories)
        let sample = HKQuantitySample(
            type: energyType,
            quantity: quantity,
            start: date,
            end: date
        )
        
        healthStore.save(sample) { success, error in
            completion(success, error)
        }
    }
}
```

**Exit Criteria:** HealthKit bridge compiles, basic read/write methods defined.

---

### 1.4.3 Flutter Platform Channel

**Files:**
- Create: `life_logger/lib/core/health/health_bridge.dart`

**Steps:**

1. **Create Dart platform channel wrapper**

```dart
import 'package:flutter/services.dart';

class HealthBridge {
  static const _channel = MethodChannel('com.lifelogger/health');
  
  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod('isAvailable');
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> requestAuthorization() async {
    try {
      return await _channel.invokeMethod('requestAuthorization');
    } catch (e) {
      return false;
    }
  }
  
  static Future<double> getSteps(DateTime date) async {
    try {
      final result = await _channel.invokeMethod('getSteps', {
        'date': date.millisecondsSinceEpoch,
      });
      return (result as num?)?.toDouble() ?? 0.0;
    } catch (e) {
      return 0.0;
    }
  }
  
  static Future<List<Map<String, dynamic>>> getWorkouts(
    DateTime startDate,
    DateTime endDate,
  ) async {
    try {
      final result = await _channel.invokeMethod('getWorkouts', {
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
      });
      return List<Map<String, dynamic>>.from(result ?? []);
    } catch (e) {
      return [];
    }
  }
  
  static Future<bool> writeWorkout({
    required String activityType,
    required DateTime startDate,
    required DateTime endDate,
    required double energyBurned,
  }) async {
    try {
      return await _channel.invokeMethod('writeWorkout', {
        'activityType': activityType,
        'startDate': startDate.millisecondsSinceEpoch,
        'endDate': endDate.millisecondsSinceEpoch,
        'energyBurned': energyBurned,
      });
    } catch (e) {
      return false;
    }
  }
  
  static Future<bool> writeNutrition({
    required double calories,
    required DateTime date,
  }) async {
    try {
      return await _channel.invokeMethod('writeNutrition', {
        'calories': calories,
        'date': date.millisecondsSinceEpoch,
      });
    } catch (e) {
      return false;
    }
  }
}
```

2. **Add method channel handler in iOS AppDelegate**

```swift
// ios/Runner/AppDelegate.swift
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        
        let controller = window?.rootViewController as! FlutterViewController
        let healthChannel = FlutterMethodChannel(
            name: "com.lifelogger/health",
            binaryMessenger: controller.binaryMessenger
        )
        
        let healthKitBridge = HealthKitBridge()
        
        healthChannel.setMethodCallHandler { (call, result) in
            switch call.method {
            case "isAvailable":
                result(healthKitBridge.isAvailable())
                
            case "requestAuthorization":
                healthKitBridge.requestAuthorization { success, error in
                    result(success)
                }
                
            case "getSteps":
                if let args = call.arguments as? [String: Any],
                   let dateMs = args["date"] as? Int {
                    let date = Date(timeIntervalSince1970: Double(dateMs) / 1000)
                    healthKitBridge.fetchSteps(date: date) { steps, error in
                        result(steps ?? 0)
                    }
                }
                
            case "getWorkouts":
                if let args = call.arguments as? [String: Any],
                   let startMs = args["startDate"] as? Int,
                   let endMs = args["endDate"] as? Int {
                    let start = Date(timeIntervalSince1970: Double(startMs) / 1000)
                    let end = Date(timeIntervalSince1970: Double(endMs) / 1000)
                    healthKitBridge.fetchWorkouts(startDate: start, endDate: end) { data, error in
                        result(data ?? [])
                    }
                }
                
            // ... handle other methods
                
            default:
                result(FlutterMethodNotImplemented)
            }
        }
        
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

**Exit Criteria:** Platform channel compiles, Dart can call iOS native methods.

---

### 1.4.4 HealthKit MCP Server (Cloud Brain)

**Files:**
- Create: `cloud-brain/app/mcp_servers/apple_health_server.py`

**Steps:**

1. **Create HealthKit MCP server**

```python
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer
from cloudbrain.app.config import settings

class AppleHealthServer(BaseMCPServer):
    """MCP server for Apple HealthKit via Edge Agent."""
    
    @property
    def name(self) -> str:
        return "apple_health"
    
    @property
    def description(self) -> str:
        return "Read and write Apple HealthKit data on the user's iOS device"
    
    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "apple_health_read_metrics",
                "description": "Read health metrics from Apple HealthKit (steps, calories, workouts, sleep)",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "data_type": {"type": "string", "enum": ["steps", "calories", "workouts", "sleep", "weight"]},
                        "start_date": {"type": "string", "description": "ISO 8601 date"},
                        "end_date": {"type": "string", "description": "ISO 8601 date"},
                    },
                    "required": ["data_type", "start_date", "end_date"]
                }
            },
            {
                "name": "apple_health_write_entry",
                "description": "Write health data to Apple HealthKit (nutrition, workout, weight)",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "data_type": {"type": "string", "enum": ["nutrition", "workout", "weight"]},
                        "value": {"type": "number"},
                        "date": {"type": "string", "description": "ISO 8601 date"},
                        "metadata": {"type": "object", "description": "Additional data (e.g., activity type for workouts)"}
                    },
                    "required": ["data_type", "value", "date"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        """Execute tool by sending command to Edge Agent via FCM or REST."""
        if tool_name == "apple_health_read_metrics":
            # In production: Send to Edge Agent via REST or FCM
            # Edge Agent returns data, we return to LLM
            return {
                "success": True,
                "data": {
                    "data_type": params["data_type"],
                    "value": 8500,
                    "unit": "steps"
                }
            }
        elif tool_name == "apple_health_write_entry":
            return {"success": True, "data": {"message": "Entry written to HealthKit"}}
        
        return {"success": False, "error": f"Unknown tool: {tool_name}"}
    
    async def get_resources(self, user_id: str) -> list[dict]:
        return [
            {"type": "recent_workouts", "description": "Workouts from the last 7 days"},
            {"type": "today_summary", "description": "Today's health summary"}
        ]
```

2. **Register server in registry**

```python
# cloud-brain/app/main.py or a setup file
from cloudbrain.app.mcp_servers.apple_health_server import AppleHealthServer
from cloudbrain.app.mcp_servers.registry import registry

registry.register(AppleHealthServer())
```

**Exit Criteria:** HealthKit MCP server compiles and is registered.

---

### 1.4.5 Edge Agent Health Repository

**Files:**
- Create: `life_logger/lib/features/health/data/health_repository.dart`

**Steps:**

1. **Create health repository**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/health/health_bridge.dart';

class HealthRepository {
  final bool _isAuthorized;
  
  HealthRepository({bool isAuthorized = false}) : _isAuthorized = isAuthorized;
  
  Future<bool> requestAuthorization() async {
    return await HealthBridge.requestAuthorization();
  }
  
  Future<bool> get isAuthorized async {
    return await HealthBridge.isAvailable();
  }
  
  Future<double> getSteps(DateTime date) async {
    return await HealthBridge.getSteps(date);
  }
  
  Future<List<Map<String, dynamic>>> getWorkouts(
    DateTime startDate,
    DateTime endDate,
  ) async {
    return await HealthBridge.getWorkouts(startDate, endDate);
  }
  
  Future<bool> writeWorkout({
    required String activityType,
    required DateTime startDate,
    required DateTime endDate,
    required double energyBurned,
  }) async {
    return await HealthBridge.writeWorkout(
      activityType: activityType,
      startDate: startDate,
      endDate: endDate,
      energyBurned: energyBurned,
    );
  }
  
  Future<bool> writeNutrition({
    required double calories,
    required DateTime date,
  }) async {
    return await HealthBridge.writeNutrition(
      calories: calories,
      date: date,
    );
  }
}
```

2. **Create Riverpod provider**

```dart
final healthRepositoryProvider = Provider<HealthRepository>((ref) {
  return HealthRepository();
});
```

**Exit Criteria:** Health repository compiles, methods bridge to native code.

---

### 1.4.6 Background Observation (HKObserverQuery)

**Files:**
- Modify: `life_logger/ios/Runner/HealthKitBridge.swift`

**Steps:**

1. **Add observer query for background updates**

```swift
func startBackgroundObservers(completion: @escaping (Bool) -> Void) {
    guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
          let workoutType = HKObjectType.workoutType() else {
        completion(false)
        return
    }
    
    let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, completionHandler, error in
        if error == nil {
            // Data changed - notify Flutter
            self?.notifyFlutterOfChange(type: "steps")
        }
        completionHandler()
    }
    
    let workoutQuery = HKObserverQuery(sampleType: workoutType, predicate: nil) { [weak self] _, completionHandler, error in
        if error == nil {
            self?.notifyFlutterOfChange(type: "workouts")
        }
        completionHandler()
    }
    
    healthStore.execute(query)
    healthStore.execute(workoutQuery)
    
    // Enable background delivery
    healthStore.enableBackgroundDelivery(for: stepType, frequency: .immediate) { _, _ in }
    healthStore.enableBackgroundDelivery(for: workoutType, frequency: .immediate) { _, _ in }
    
    completion(true)
}

private func notifyFlutterOfChange(type: String) {
    // Send via method channel to Flutter
    // Flutter will then sync to Cloud Brain
}
```

**Exit Criteria:** Background observers defined for detecting third-party app writes.

---

### 1.4.7 Harness Test: HealthKit Integration

**Files:**
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Add HealthKit buttons to harness**

```dart
// Add to harness screen:
ElevatedButton(
  onPressed: () async {
    final healthRepo = ref.read(healthRepositoryProvider);
    final authorized = await healthRepo.requestAuthorization();
    _outputController.text = authorized 
        ? 'HealthKit AUTHORIZED' 
        : 'HealthKit DENIED';
  },
  child: const Text('Request HealthKit'),
),

ElevatedButton(
  onPressed: () async {
    final healthRepo = ref.read(healthRepositoryProvider);
    final steps = await healthRepo.getSteps(DateTime.now());
    _outputController.text = 'Steps today: $steps';
  },
  child: const Text('Read Steps'),
),

ElevatedButton(
  onPressed: () async {
    final healthRepo = ref.read(healthRepositoryProvider);
    final workouts = await healthRepo.getWorkouts(
      DateTime.now().subtract(const Duration(days: 7)),
      DateTime.now(),
    );
    _outputController.text = 'Workouts: ${workouts.length}';
  },
  child: const Text('Read Workouts'),
),
```

**Exit Criteria:** Harness shows HealthKit buttons, can request authorization, read data.

---

### 1.4.8 Apple Health Integration Document

**Files:**
- Create: `docs/plans/integrations/apple-health-integration.md`

**Steps:**

1. **Create integration reference document** with:
   - API overview
   - Data types available
   - Permission requirements
   - Background delivery setup
   - Code examples
   - Testing checklist

**Exit Criteria:** Integration document created in `docs/plans/integrations/`.

---

**Phase 1.4 Exit Criteria:**
- [ ] HealthKit entitlements configured in Xcode
- [ ] Swift HealthKit bridge implemented
- [ ] Flutter platform channel wrapper created
- [ ] Cloud Brain MCP server created and registered
- [ ] Edge Agent health repository implemented
- [ ] Background observer queries set up
- [ ] Harness test buttons work (auth, read steps, read workouts)
- [ ] Integration document created

---

## Phase 1.5: Google Health Connect Integration

> **Reference:** See `integrations/google-health-connect-integration.md` for deep dive.

**Goal:** Implement read/write access to Google Health Connect on Android via Flutter platform channels.

**Depends On:** Phase 1.4 (Apple HealthKit - similar pattern)  
**Estimated Duration:** 5-6 days

### 1.5.1 Health Connect Permissions (Android)

**Files:**
- Modify: `life_logger/android/app/src/main/AndroidManifest.xml`
- Create: `life_logger/android/app/src/main/res/xml/health_permissions.xml`

**Steps:**

1. **Add permissions to AndroidManifest**

```xml
<uses-permission android:name="android.permission.health.READ_STEPS"/>
<uses-permission android:name="android.permission.health.WRITE_STEPS"/>
<uses-permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.WRITE_ACTIVE_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.READ_TOTAL_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.WRITE_TOTAL_CALORIES_BURNED"/>
<uses-permission android:name="android.permission.health.READ_SLEEP"/>
<uses-permission android:name="android.permission.health.READ_WEIGHT"/>
<uses-permission android:name="android.permission.health.WRITE_WEIGHT"/>
<uses-permission android:name="android.permission.health.READ_EXERCISE"/>
<uses-permission android:name="android.permission.health.WRITE_EXERCISE"/>
```

2. **Create health_permissions.xml**

```xml
<health-permissions>
    <permission android:name="android.permission.health.READ_STEPS"/>
    <permission android:name="android.permission.health.WRITE_STEPS"/>
    <permission android:name="android.permission.health.READ_ACTIVE_CALORIES_BURNED"/>
    <permission android:name="android.permission.health.WRITE_ACTIVE_CALORIES_BURNED"/>
    <permission android:name="android.permission.health.READ_SLEEP"/>
    <permission android:name="android.permission.health.READ_WEIGHT"/>
    <permission android:name="android.permission.health.WRITE_WEIGHT"/>
    <permission android:name="android.permission.health.READ_EXERCISE"/>
    <permission android:name="android.permission.health.WRITE_EXERCISE"/>
</health-permissions>
```

**Exit Criteria:** AndroidManifest updated with Health Connect permissions.

---

### 1.5.2 Kotlin Health Connect Bridge

**Files:**
- Create: `life_logger/android/app/src/main/kotlin/com/lifelogger/HealthConnectBridge.kt`

**Steps:**

1. **Create Health Connect bridge**

```kotlin
package com.lifelogger

import android.content.Context
import androidx.health.connect.client.HealthConnectClient
import androidx.health.connect.client.PermissionController
import androidx.health.connect.client.permission.HealthPermission
import androidx.health.connect.client.records.*
import androidx.health.connect.client.request.ReadRecordsRequest
import androidx.health.connect.client.time.TimeRangeFilter
import kotlinx.coroutines.runBlocking
import java.time.Instant

class HealthConnectBridge(private val context: Context) {
    
    private val healthConnectClient: HealthConnectClient? by lazy {
        HealthConnectClient.getOrCreate(context)
    }
    
    val permissions = setOf(
        HealthPermission.getReadPermission(StepsRecord::class),
        HealthPermission.getWritePermission(StepsRecord::class),
        HealthPermission.getReadPermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getWritePermission(ActiveCaloriesBurnedRecord::class),
        HealthPermission.getReadPermission(SleepRecord::class),
        HealthPermission.getReadPermission(BodyWeightRecord::class),
        HealthPermission.getWritePermission(BodyWeightRecord::class),
        HealthPermission.getReadPermission(ExerciseSessionRecord::class),
        HealthPermission.getWritePermission(ExerciseSessionRecord::class),
    )
    
    fun isAvailable(): Boolean {
        return HealthConnectClient.getSdkStatus(context) == HealthConnectClient.SDK_AVAILABLE
    }
    
    fun requestPermissions(): Boolean {
        // This returns the permissions to request - actual request happens in Flutter
        return true
    }
    
    fun readSteps(startTime: Long, endTime: Long): Int {
        val client = healthConnectClient ?: return 0
        
        return runBlocking {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = StepsRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startTime),
                        Instant.ofEpochMilli(endTime)
                    )
                )
            )
            response.records.sumOf { it.count.toInt() }
        }
    }
    
    fun readWorkouts(startTime: Long, endTime: Long): List<Map<String, Any>> {
        val client = healthConnectClient ?: return emptyList()
        
        return runBlocking {
            val response = client.readRecords(
                ReadRecordsRequest(
                    recordType = ExerciseSessionRecord::class,
                    timeRangeFilter = TimeRangeFilter.between(
                        Instant.ofEpochMilli(startTime),
                        Instant.ofEpochMilli(endTime)
                    )
                )
            )
            response.records.map { workout ->
                mapOf(
                    "title" to workout.title,
                    "startTime" to workout.startTime.toEpochMilli(),
                    "endTime" to workout.endTime.toEpochMilli(),
                    "duration" to workout.duration?.toMillis(),
                )
            }
        }
    }
    
    fun writeNutrition(calories: Double, startTime: Long): Boolean {
        val client = healthConnectClient ?: return false
        
        return runBlocking {
            try {
                val record = NutritionRecord(
                    startTime = Instant.ofEpochMilli(startTime),
                    endTime = Instant.ofEpochMilli(startTime),
                    energy = Energy.calories(calories)
                )
                client.insertRecords(listOf(record))
                true
            } catch (e: Exception) {
                false
            }
        }
    }
}
```

**Exit Criteria:** Health Connect bridge compiles, read/write methods defined.

---

### 1.5.3 Flutter Platform Channel (Android)

**Files:**
- Modify: `life_logger/lib/core/health/health_bridge.dart`
- Modify: `life_logger/android/app/src/main/kotlin/com/lifelogger/MainActivity.kt`

**Steps:**

1. **Add Android method channel handler**

```kotlin
// MainActivity.kt
package com.lifelogger

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.lifelogger/health"
    private lateinit var healthConnectBridge: HealthConnectBridge
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        healthConnectBridge = HealthConnectBridge(this)
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "isAvailable" -> result.success(healthConnectBridge.isAvailable())
                "requestPermissions" -> result.success(healthConnectBridge.requestPermissions())
                "getSteps" -> {
                    val startDate = call.argument<Long>("startDate") ?: 0
                    val endDate = call.argument<Long>("endDate") ?: System.currentTimeMillis()
                    result.success(healthConnectBridge.readSteps(startDate, endDate))
                }
                "getWorkouts" -> {
                    val startDate = call.argument<Long>("startDate") ?: 0
                    val endDate = call.argument<Long>("endDate") ?: System.currentTimeMillis()
                    result.success(healthConnectBridge.readWorkouts(startDate, endDate))
                }
                "writeNutrition" -> {
                    val calories = call.argument<Double>("calories") ?: 0.0
                    val date = call.argument<Long>("date") ?: System.currentTimeMillis()
                    result.success(healthConnectBridge.writeNutrition(calories, date))
                }
                else -> result.notImplemented()
            }
        }
    }
}
```

2. **Update Dart health bridge to handle both platforms**

```dart
import 'dart:io';
import 'package:flutter/services.dart';

class HealthBridge {
  static const _channel = MethodChannel('com.lifelogger/health');
  
  static Future<bool> isAvailable() async {
    try {
      return await _channel.invokeMethod('isAvailable');
    } catch (e) {
      return false;
    }
  }
  
  // Methods for both iOS and Android - platform handles routing
  static Future<double> getSteps({DateTime? startDate, DateTime? endDate}) async {
    // Implementation...
  }
}
```

**Exit Criteria:** Both iOS and Android platform channels work via same Dart interface.

---

### 1.5.4 Health Connect MCP Server

**Files:**
- Create: `cloud-brain/app/mcp_servers/health_connect_server.py`

**Steps:**

1. **Create Health Connect MCP server**

```python
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer

class HealthConnectServer(BaseMCPServer):
    """MCP server for Google Health Connect via Edge Agent."""
    
    @property
    def name(self) -> str:
        return "health_connect"
    
    @property
    def description(self) -> str:
        return "Read and write health data on Android via Google Health Connect"
    
    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "health_connect_read_metrics",
                "description": "Read health metrics from Google Health Connect",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "data_type": {"type": "string", "enum": ["steps", "calories", "workouts", "sleep", "weight"]},
                        "start_date": {"type": "string"},
                        "end_date": {"type": "string"},
                    },
                    "required": ["data_type", "start_date", "end_date"]
                }
            },
            {
                "name": "health_connect_write_entry",
                "description": "Write health data to Google Health Connect",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "data_type": {"type": "string", "enum": ["nutrition", "weight"]},
                        "value": {"type": "number"},
                        "date": {"type": "string"},
                    },
                    "required": ["data_type", "value", "date"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        # Similar to Apple HealthKit - send to Edge Agent
        return {"success": True, "data": {}}
    
    async def get_resources(self, user_id: str) -> list[dict]:
        return [{"type": "recent_workouts"}, {"type": "today_summary"}]
```

2. **Register in registry**

```python
from cloudbrain.app.mcp_servers.health_connect_server import HealthConnectServer
registry.register(HealthConnectServer())
```

**Exit Criteria:** Health Connect MCP server registered and compiles.

---

### 1.5.5 Background Sync (Android WorkManager)

**Files:**
- Create: `life_logger/android/app/src/main/kotlin/com/lifelogger/HealthSyncWorker.kt`

**Steps:**

1. **Create WorkManager worker**

```kotlin
package com.lifelogger

import android.content.Context
import androidx.work.*
import java.util.concurrent.TimeUnit

class HealthSyncWorker(
    context: Context,
    params: WorkerParameters
) : CoroutineWorker(context, params) {
    
    override suspend fun doWork(): Result {
        // 1. Read data from Health Connect
        // 2. Send to Cloud Brain via REST API
        // 3. Return success/failure
        return Result.success()
    }
    
    companion object {
        fun schedule(context: Context) {
            val constraints = Constraints.Builder()
                .setRequiredNetworkType(NetworkType.CONNECTED)
                .build()
            
            val request = PeriodicWorkRequestBuilder<HealthSyncWorker>(
                15, TimeUnit.MINUTES
            )
                .setConstraints(constraints)
                .build()
            
            WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                "health_sync",
                ExistingPeriodicWorkPolicy.KEEP,
                request
            )
        }
    }
}
```

**Exit Criteria:** WorkManager worker created for background sync.

---

### 1.5.6 Unified Health Store Abstraction

**Files:**
- Create: `life_logger/lib/core/health/health_observer.dart`

**Steps:**

1. **Create unified health observer**

```dart
import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HealthObserver {
  final bool isAndroid;
  
  HealthObserver() : isAndroid = Platform.isAndroid;
  
  Future<void> startObserving({
    required Function(String dataType) onDataChanged,
  }) async {
    if (isAndroid) {
      // Start WorkManager periodic sync
      // Start observers via platform channel
    } else {
      // Start HKObserverQuery via platform channel
    }
  }
  
  Future<void> stopObserving() async {
    // Stop observers
  }
}
```

**Exit Criteria:** Unified observer can start/stop for both platforms.

---

### 1.5.7 Health Connect Integration Document

**Files:**
- Create: `docs/plans/integrations/google-health-connect-integration.md`

**Steps:**

1. **Create integration reference document** with:
   - Health Connect API overview
   - Permission requirements
   - Platform-specific implementation notes
   - Testing checklist for Android

**Exit Criteria:** Integration document created.

---

**Phase 1.5 Exit Criteria:**
- [ ] Health Connect permissions in AndroidManifest
- [ ] Kotlin Health Connect bridge implemented
- [ ] Flutter platform channel handles both iOS/Android
- [ ] Health Connect MCP server created and registered
- [ ] WorkManager background sync implemented
- [ ] Unified health observer abstraction
- [ ] Integration document created

---

## Phase 1.6: Strava Integration

> **Reference:** See `integrations/strava-integration.md` for deep dive.

**Goal:** Implement Strava OAuth flow and activity read/write via MCP server.

**Depends On:** Phase 1.3 (MCP Base Framework)  
**Estimated Duration:** 5-6 days

### 1.6.1 Strava API Setup

**Files:**
- Modify: `cloud-brain/app/config.py`
- Create: `cloud-brain/app/.env.example`

**Steps:**

1. **Configure Strava credentials**

```python
# In config.py
strava_client_id: str
strava_client_secret: str
strava_redirect_uri: str = "lifelogger://oauth/strava"
```

2. **Create .env.example**

```
STRAVA_CLIENT_ID=your_client_id
STRAVA_CLIENT_SECRET=your_client_secret
STRAVA_REDIRECT_URI=lifelogger://oauth/strava
```

3. **Register app in Strava Developers**

- Go to https://www.strava.com/settings/api
- Create application
- Note Client ID and Client Secret

**Exit Criteria:** Strava API credentials obtained and configured.

---

### 1.6.2 Strava OAuth Flow (Cloud Brain)

**Files:**
- Create: `cloud-brain/app/api/v1/integrations.py`

**Steps:**

1. **Create OAuth endpoints**

```python
from fastapi import APIRouter, Query
from cloudbrain.app.config import settings

router = APIRouter(prefix="/integrations", tags=["integrations"])

@router.get("/strava/authorize")
async def strava_authorize():
    """Get Strava OAuth URL."""
    import urllib.parse
    params = {
        'client_id': settings.strava_client_id,
        'redirect_uri': settings.strava_redirect_uri,
        'response_type': 'code',
        'scope': 'read,activity:read,activity:write',
    }
    auth_url = f"https://www.strava.com/oauth/authorize?{urllib.parse.urlencode(params)}"
    return {"auth_url": auth_url}

@router.get("/strava/callback")
async def strava_callback(code: str = Query(...), user_id: str = Query(...)):
    """Exchange code for tokens."""
    import httpx
    
    async with httpx.AsyncClient() as client:
        response = await client.post(
            "https://www.strava.com/oauth/token",
            data={
                'client_id': settings.strava_client_id,
                'client_secret': settings.strava_client_secret,
                'code': code,
                'grant_type': 'authorization_code',
            }
        )
        
    token_data = response.json()
    
    # Save tokens to database
    # integration = Integration(
    #     user_id=user_id,
    #     provider='strava',
    #     access_token=token_data['access_token'],
    #     refresh_token=token_data['refresh_token'],
    #     token_expires_at=datetime.fromtimestamp(token_data['expires_at']),
    # )
    # await db.commit()
    
    return {"success": True, "message": "Strava connected!"}
```

**Exit Criteria:** OAuth flow endpoints created, can exchange code for tokens.

---

### 1.6.3 Strava MCP Server

**Files:**
- Create: `cloud-brain/app/mcp_servers/strava_server.py`

**Steps:**

1. **Create Strava MCP server**

```python
import httpx
from cloudbrain.app.mcp_servers.base_server import BaseMCPServer
from cloudbrain.app.config import settings

class StravaServer(BaseMCPServer):
    """MCP server for Strava API."""
    
    @property
    def name(self) -> str:
        return "strava"
    
    @property
    def description(self) -> str:
        return "Read and write Strava activities"
    
    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "strava_get_activities",
                "description": "Get recent activities from Strava",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "user_id": {"type": "string"},
                        "limit": {"type": "integer", "default": 30},
                        "page": {"type": "integer", "default": 1},
                    },
                    "required": ["user_id"]
                }
            },
            {
                "name": "strava_create_activity",
                "description": "Create a manual activity in Strava",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "user_id": {"type": "string"},
                        "name": {"type": "string"},
                        "type": {"type": "string", "enum": ["Run", "Ride", "Swim", "Workout", "Other"]},
                        "distance": {"type": "number", "description": "in meters"},
                        "elapsed_time": {"type": "integer", "description": "in seconds"},
                        "start_date_local": {"type": "string", "description": "ISO 8601"},
                    },
                    "required": ["user_id", "name", "type", "distance", "elapsed_time"]
                }
            },
            {
                "name": "strava_get_athlete_stats",
                "description": "Get athlete statistics from Strava",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "user_id": {"type": "string"},
                    },
                    "required": ["user_id"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        # Get user tokens from database
        tokens = await self._get_user_tokens(user_id)
        if not tokens:
            return {"success": False, "error": "Strava not connected"}
        
        # Refresh token if needed
        tokens = await self._ensure_valid_token(tokens, user_id)
        
        if tool_name == "strava_get_activities":
            return await self._get_activities(tokens, params.get('limit', 30), params.get('page', 1))
        elif tool_name == "strava_create_activity":
            return await self._create_activity(tokens, params)
        elif tool_name == "strava_get_athlete_stats":
            return await self._get_athlete_stats(tokens)
        
        return {"success": False, "error": f"Unknown tool: {tool_name}"}
    
    async def _get_activities(self, tokens: dict, limit: int, page: int) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.get(
                "https://www.strava.com/api/v3/athlete/activities",
                headers={"Authorization": f"Bearer {tokens['access_token']}"},
                params={"per_page": limit, "page": page}
            )
        
        if response.status_code == 200:
            return {"success": True, "data": response.json()}
        return {"success": False, "error": response.text}
    
    async def _create_activity(self, tokens: dict, params: dict) -> dict:
        async with httpx.AsyncClient() as client:
            response = await client.post(
                "https://www.strava.com/api/v3/activities",
                headers={"Authorization": f"Bearer {tokens['access_token']}"},
                json={
                    "name": params["name"],
                    "type": params["type"],
                    "distance": params["distance"],
                    "elapsed_time": params["elapsed_time"],
                    "start_date_local": params.get("start_date_local"),
                }
            )
        
        if response.status_code == 201:
            return {"success": True, "data": response.json()}
        return {"success": False, "error": response.text}
    
    async def _get_athlete_stats(self, tokens: dict) -> dict:
        athlete_id = tokens.get('athlete_id')
        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"https://www.strava.com/api/v3/athletes/{athlete_id}/stats",
                headers={"Authorization": f"Bearer {tokens['access_token']}"}
            )
        
        if response.status_code == 200:
            return {"success": True, "data": response.json()}
        return {"success": False, "error": response.text}
    
    async def get_resources(self, user_id: str) -> list[dict]:
        return [{"type": "recent_activities"}, {"type": "athlete_profile"}]
```

2. **Register in registry**

```python
from cloudbrain.app.mcp_servers.strava_server import StravaServer
registry.register(StravaServer())
```

**Exit Criteria:** Strava MCP server compiles, can fetch and create activities.

---

### 1.6.4 Edge Agent OAuth Flow

**Files:**
- Create: `life_logger/lib/features/integrations/data/oauth_repository.dart`

**Steps:**

1. **Create OAuth repository**

```dart
import 'package:dio/dio.dart';
import 'package:flutter_webview_plugin/flutter_webview_plugin.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

class OAuthRepository {
  final ApiClient _apiClient;
  final SecureStorage _secureStorage;
  
  OAuthRepository({required ApiClient apiClient, required SecureStorage secureStorage})
      : _apiClient = apiClient,
        _secureStorage = secureStorage;
  
  Future<String?> getStravaAuthUrl() async {
    try {
      final response = await _apiClient.get('/integrations/strava/authorize');
      return response.data['auth_url'];
    } catch (e) {
      return null;
    }
  }
  
  Future<bool> handleStravaCallback(String code) async {
    try {
      // In practice, the callback is handled by Cloud Brain directly
      // via deep link back to the app
      final response = await _apiClient.get('/integrations/strava/callback', queryParameters: {
        'code': code,
      });
      return response.data['success'] ?? false;
    } catch (e) {
      return false;
    }
  }
}
```

**Exit Criteria:** OAuth repository compiles.

---

### 1.6.5 Deep Link Handling for OAuth

**Files:**
- Modify: `life_logger/lib/main.dart`
- Create: `life_logger/lib/core/deeplink/deeplink_handler.dart`

**Steps:**

1. **Configure deep links**

```dart
// In main.dart
void main() {
  runApp(
    ProviderScope(
      child: LifeLoggerApp(
        onDeepLink: (uri) => handleDeepLink(uri),
      ),
    ),
  );
}

void handleDeepLink(Uri uri) {
  if (uri.host == 'oauth' && uri.path == '/strava') {
    final code = uri.queryParameters['code'];
    if (code != null) {
      // Handle Strava OAuth callback
    }
  }
}
```

2. **Configure iOS deep links**

```xml
<!-- ios/Runner/Info.plist -->
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleTypeRole</key>
        <string>Editor</string>
        <key>CFBundleURLName</key>
        <string>com.lifelogger</string>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>lifelogger</string>
        </array>
    </dict>
</array>
```

**Exit Criteria:** Deep links configured for OAuth callback.

---

### 1.6.6 Strava WebView Button in Harness

**Files:**
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Add Strava button to harness**

```dart
ElevatedButton(
  onPressed: () async {
    final oauthRepo = ref.read(oauthRepositoryProvider);
    final authUrl = await oauthRepo.getStravaAuthUrl();
    if (authUrl != null) {
      // Open WebView with authUrl
      // Handle callback
      _outputController.text = 'Strava OAuth URL: $authUrl';
    } else {
      _outputController.text = 'Failed to get Strava auth URL';
    }
  },
  child: const Text('Connect Strava'),
),

ElevatedButton(
  onPressed: () async {
    // Fetch recent Strava activities via API
    _outputController.text = 'Fetching Strava activities...';
    // Call Cloud Brain endpoint
    // Display results
  },
  child: const Text('Fetch Strava Runs'),
),
```

**Exit Criteria:** Harness shows Strava buttons, can initiate OAuth, fetch activities.

---

### 1.6.7 Strava Integration Document

**Files:**
- Create: `docs/plans/integrations/strava-integration.md`

**Steps:**

1. **Create integration reference document** with:
   - Strava API v3 overview
   - OAuth flow details
   - Rate limits
   - Available endpoints
   - Webhook support

**Exit Criteria:** Integration document created.

---

**Phase 1.6 Exit Criteria:**
- [ ] Strava API credentials obtained
- [ ] OAuth flow endpoints implemented
- [ ] Strava MCP server created and registered
- [ ] Edge Agent OAuth repository implemented
- [ ] Deep link handling configured
- [ ] Harness shows Strava buttons and can fetch activities
- [ ] Integration document created

---

## Phase 1.7: CalAI Integration (Zero-Friction)

> **Reference:** See `integrations/calai-integration.md` for deep dive.

**Goal:** Implement zero-friction CalAI integration via deep linking and Health Store reading (NOT direct API).

**Depends On:** Phase 1.4 (Apple HealthKit) and Phase 1.5 (Google Health Connect)  
**Estimated Duration:** 3-4 days

### 1.7.1 CalAI Deep Link Strategy

**Files:**
- Modify: `life_logger/lib/core/deeplink/deeplink_launcher.dart`

**Steps:**

1. **Create deep link launcher**

```dart
import 'package:url_launcher/url_launcher.dart';

class DeepLinkLauncher {
  static const _calaiScheme = 'calai';
  static const _stravaScheme = 'strava';
  
  static Future<bool> openCalAI() async {
    final uri = Uri.parse('calai://');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    // Fallback to web
    final webUri = Uri.parse('https://calai.com/app');
    return await launchUrl(webUri, mode: LaunchMode.externalApplication);
  }
  
  static Future<bool> openStravaRecord({String sport = 'running'}) async {
    final uri = Uri.parse('strava://record?sport=$sport');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }
  
  static Future<bool> openMyFitnessPal() async {
    final uri = Uri.parse('mfp://');
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri);
    }
    return false;
  }
}
```

**Exit Criteria:** Deep link launcher can open CalAI, Strava recording, MyFitnessPal.

---

### 1.7.2 Nutrition Data Flow via Health Store

**Files:**
- Modify: `cloud-brain/app/mcp_servers/apple_health_server.py`
- Modify: `cloud-brain/app/mcp_servers/health_connect_server.py`

**Steps:**

1. **Add nutrition reading to HealthKit MCP server**

```python
# In apple_health_server.py
async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
    if tool_name == "apple_health_read_metrics":
        data_type = params.get("data_type")
        
        if data_type == "nutrition":
            # Return nutrition data from Apple Health
            # (CalAI writes to Apple Health when user logs food)
            return {
                "success": True,
                "data": {
                    "total_calories": 1850,
                    "protein_grams": 95,
                    "carbs_grams": 180,
                    "fat_grams": 65,
                    "meals": [
                        {"name": "Grilled Chicken Salad", "calories": 420, "time": "2026-02-18T12:30:00Z"},
                        {"name": "Banana", "calories": 105, "time": "2026-02-18T10:00:00Z"},
                    ]
                }
            }
```

**Exit Criteria:** MCP servers can read nutrition data from Health Stores.

---

### 1.7.3 CalAI Integration Document

**Files:**
- Create: `docs/plans/integrations/calai-integration.md`

**Steps:**

1. **Create integration reference document** with:
   - Zero-Friction strategy explanation
   - Deep link URI schemes
   - Data flow via Health Stores
   - Future direct API considerations

**Exit Criteria:** Integration document created.

---

**Phase 1.7 Exit Criteria:**
- [ ] Deep link launcher can open CalAI
- [ ] Nutrition data readable via Health Store MCP
- [ ] Integration document created

---

## Phase 1.8: The AI Brain (Reasoning Engine)

> **Reference:** Review `integrations/ai-brain-integration.md` for LLM selection (OpenRouter + Kimi K2.5).

**Goal:** Implement the LLM agent that orchestrates MCP tools, performs cross-app reasoning, and generates responses.

**Depends On:** Phase 1.3 (MCP Base Framework), Phase 1.4-1.7 (Integrations)  
**Estimated Duration:** 6-7 days

### 1.8.1 LLM Client Setup

**Files:**
- Create: `cloud-brain/app/agent/llm_client.py`

**Steps:**

1. **Create OpenAI-compatible LLM client**

```python
import httpx
from cloudbrain.app.config import settings

class LLMClient:
    """Client for Kimi K2.5 via OpenRouter."""
    
    def __init__(self, model: str = "moonshot/kimi-k2.5"):
        self.model = model
        self.base_url = "https://openrouter.ai/api/v1"
        self.api_key = settings.openrouter_api_key
        self.referer = settings.openrouter_referer
        self.title = settings.openrouter_title
    
    async def chat(self, messages: list[dict], tools: list[dict] | None = None) -> dict:
        """Send chat request to LLM via OpenRouter."""
        payload = {
            "model": self.model,
            "messages": messages,
            "temperature": 0.7,
        }
        
        if tools:
            payload["tools"] = tools
        
        async with httpx.AsyncClient() as client:
            response = await client.post(
                f"{self.base_url}/chat/completions",
                headers={
                    "Authorization": f"Bearer {self.api_key}",
                    "Content-Type": "application/json",
                    "HTTP-Referer": self.referer,
                    "X-Title": self.title,
                },
                json=payload,
                timeout=60.0
            )
        
        return response.json()
    
    async def stream_chat(self, messages: list[dict], tools: list[dict] | None = None):
        """Stream chat response from LLM."""
        # Implementation for streaming
        pass
```

**Exit Criteria:** LLM client can send requests to OpenRouter (Kimi K2.5).

---

### 1.8.2 Agent System Prompt

**Files:**
- Create: `cloud-brain/app/agent/prompts/system.py`

**Steps:**

1. **Create system prompt**

```python
SYSTEM_PROMPT = """You are Life Logger, an AI health assistant with a "Tough Love Coach" persona.

## Your Capabilities
- You can read data from Apple Health, Google Health Connect, Strava, Fitbit, and Oura
- You can write nutrition entries and workouts to Apple Health / Health Connect
- You can create manual activities in Strava
- You can open external apps (CalAI, Strava, MyFitnessPal) via deep links

## Your Personality
- Opinionated and direct: You don't just report data, you interpret it
- Context-aware: You consider sleep, nutrition, and activity together
- Proactive: You suggest actions, not just answer questions

## Guidelines
- Always be helpful but honest
- When users ask "why am I not losing weight?", analyze nutrition AND activity AND sleep
- Use specific numbers from their data
- Suggest actionable next steps
- If you need more data to answer a question, ask for it

## Data Privacy
- Never share sensitive health data in your responses
- Focus on insights and trends, not raw data dumps
"""
```

**Exit Criteria:** System prompt defined and imported by orchestrator.

---

### 1.8.3 Tool Selection Logic

**Files:**
- Modify: `cloud-brain/app/agent/orchestrator.py`

**Steps:**

1. **Implement tool selection**

```python
async def process_message(self, user_id: str, message: str) -> str:
    # 1. Get user context from Pinecone
    context = await self.context_manager.get_context(user_id)
    
    # 2. Build messages with system prompt
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": message}
    ]
    
    # 3. Get available tools
    tools = self.mcp_client.get_all_tools()
    
    # 4. Send to LLM
    response = await self.llm_client.chat(messages, tools=tools)
    
    # 5. Check if LLM wants to call tools
    if "choices" in response:
        choice = response["choices"][0]
        if "tool_calls" in choice.get("message", {}):
            # Execute tools and loop
            tool_calls = choice["message"]["tool_calls"]
            for tool_call in tool_calls:
                result = await self.mcp_client.execute_tool(
                    tool_name=tool_call["function"]["name"],
                    params=tool_call["function"]["arguments"],
                    user_id=user_id
                )
                # Add result to messages and continue
                messages.append({
                    "role": "assistant",
                    "content": None,
                    "tool_calls": [tool_call]
                })
                messages.append({
                    "role": "tool",
                    "tool_call_id": tool_call["id"],
                    "content": str(result)
                })
            
            # Get final response after tool execution
            final_response = await self.llm_client.chat(messages)
            return final_response["choices"][0]["message"]["content"]
        
        return choice.get("message", {}).get("content", "")
    
    return "I'm having trouble processing that."
```

**Exit Criteria:** Orchestrator can call LLM, detect tool calls, execute tools, and return response.

---

### 1.8.4 Cross-App Reasoning Engine

**Files:**
- Create: `cloud-brain/app/analytics/reasoning_engine.py`

**Steps:**

1. **Create reasoning engine**

```python
import statistics

class ReasoningEngine:
    """Analyzes cross-app data to generate insights."""
    
    def analyze_weight_loss_correlation(
        self,
        nutrition_data: list[dict],
        activity_data: list[dict],
        weight_data: list[dict]
    ) -> dict:
        """Analyze why user might not be losing weight."""
        
        # Calculate average daily calories
        avg_calories = statistics.mean([d.get("calories", 0) for d in nutrition_data])
        
        # Calculate activity burn
        total_activity_burn = sum(d.get("calories_burned", 0) for d in activity_data)
        avg_daily_burn = total_activity_burn / max(len(activity_data), 1)
        
        # Estimate maintenance
        # (Simplified - in production use Mifflin-St Jeor or similar)
        estimated_maintenance = 2000  # Would come from user profile
        
        # Calculate deficit/surplus
        daily_surplus = avg_calories - estimated_maintenance + avg_daily_burn
        
        # Analyze activity trends
        this_month_activities = [a for a in activity_data if a.get("date", "").startswith("2026-02")]
        last_month_activities = [a for a in activity_data if a.get("date", "").startswith("2026-01")]
        
        activity_change = len(this_month_activities) - len(last_month_activities)
        
        return {
            "avg_daily_calories": round(avg_calories),
            "avg_daily_burn": round(avg_daily_burn),
            "estimated_maintenance": estimated_maintenance,
            "daily_surplus": round(daily_surplus),
            "activity_change": activity_change,
            "insight": self._generate_insight(daily_surplus, activity_change)
        }
    
    def _generate_insight(self, surplus: float, activity_change: int) -> str:
        if surplus > 200:
            return f"You're eating ~{int(surplus)} calories above maintenance. That's why the scale isn't moving."
        elif activity_change < -2:
            return f"Your activity dropped significantly ({activity_change} sessions vs last month). That's impacting your progress."
        else:
            return "Your data looks consistent. Keep going!"
```

**Exit Criteria:** Reasoning engine can analyze cross-app data and generate insights.

---

### 1.8.5 Voice Input (Whisper STT)

**Files:**
- Create: `cloud-brain/app/api/v1/chat.py`

**Steps:**

1. **Add voice transcription endpoint**

```python
@router.post("/transcribe")
async def transcribe_audio(file: UploadFile):
    """Transcribe audio using OpenAI Whisper."""
    import openai
    
    # Save uploaded file temporarily
    with tempfile.NamedTemporaryFile(delete=False, suffix=".webm") as tmp:
        content = await file.read()
        tmp.write(content)
        tmp_path = tmp.name
    
    # Transcribe
    audio_file = open(tmp_path, "rb")
    transcript = openai.Audio.transcribe("whisper-1", audio_file)
    
    os.unlink(tmp_path)
    
    return {"text": transcript["text"]}
```

**Exit Criteria:** Voice transcription endpoint compiles.

---

### 1.8.6 User Profile & Preferences

**Files:**
- Create: `cloud-brain/app/agent/context_manager/user_profile_manager.py`

**Steps:**

1. **Create user profile manager**

```python
class UserProfileManager:
    """Manages user profile and coach preferences."""
    
    async def get_profile(self, user_id: str) -> dict:
        """Get user profile with coach preferences."""
        # Query from database
        return {
            "coach_persona": "tough_love",  # gentle, balanced, tough_love
            "goals": {
                "target_weight": 165,
                "weekly_run_target": 3,
                "daily_calorie_target": 2000,
            },
            "connected_apps": ["strava", "apple_health"],
        }
    
    async def update_persona(self, user_id: str, persona: str) -> bool:
        """Update user's coach persona preference."""
        # Update in database
        return True
```

**Exit Criteria:** User profile manager can get/update profile.

---

### 1.8.7 Test Harness: AI Chat

**Files:**
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Add AI chat test to harness**

```dart
final _chatInputController = TextEditingController();

ElevatedButton(
  onPressed: () async {
    final apiClient = ref.read(apiClientProvider);
    final response = await apiClient.post('/chat', data: {
      'message': _chatInputController.text,
    });
    _outputController.text = response.data['response'];
  },
  child: const Text('Send to AI'),
),

TextField(
  controller: _chatInputController,
  decoration: const InputDecoration(
    labelText: 'Chat message',
    border: OutlineInputBorder(),
  ),
),
```

**Exit Criteria:** Harness can send messages to AI and display responses.

---

### 1.8.8 Kimi Integration Document

**Files:**
- Create: `docs/plans/integrations/ai-brain-integration.md`

**Steps:**

1. **Create AI Brain integration document** with:
   - LLM configuration
   - Tool schemas
   - System prompts
   - Reasoning patterns

**Exit Criteria:** Integration document created.

---

**Phase 1.8 Exit Criteria:**
- [ ] LLM client can call OpenRouter (Kimi K2.5)
- [ ] System prompt defined for "Tough Love Coach"
- [ ] Tool selection logic implemented in orchestrator
- [ ] Cross-app reasoning engine created
- [ ] Voice transcription endpoint
- [ ] User profile manager
- [ ] Harness can chat with AI
- [ ] AI Brain integration document

---

### 1.8.4 Rate Limiter Service

**Files:**
- Create: `cloud-brain/app/services/rate_limiter.py`

**Steps:**

1. **Create rate limiter service**

```python
# cloud-brain/app/services/rate_limiter.py
import redis.asyncio as redis
from cloudbrain.app.config import settings

class RateLimiter:
    def __init__(self):
        self.redis = redis.from_url(settings.redis_url)
    
    async def check_limit(self, user_id: str, tier: str = "free") -> bool:
        """Check if user has not exceeded rate limit."""
        limits = {
            "free": {"requests_per_minute": 10, "requests_per_day": 100},
            "premium": {"requests_per_minute": 60, "requests_per_day": 1000},
            "enterprise": {"requests_per_minute": 120, "requests_per_day": 10000}
        }
        
        tier_limits = limits.get(tier, limits["free"])
        
        minute_key = f"ratelimit:{user_id}:minute"
        day_key = f"ratelimit:{user_id}:day"
        
        minute_count = await self.redis.get(minute_key)
        if minute_count and int(minute_count) >= tier_limits["requests_per_minute"]:
            return False
        
        day_count = await self.redis.get(day_key)
        if day_count and int(day_count) >= tier_limits["requests_per_day"]:
            return False
        
        return True
    
    async def increment(self, user_id: str):
        """Increment rate limit counters."""
        minute_key = f"ratelimit:{user_id}:minute"
        day_key = f"ratelimit:{user_id}:day"
        
        pipe = self.redis.pipeline()
        pipe.incr(minute_key)
        pipe.expire(minute_key, 60)
        pipe.incr(day_key)
        pipe.expire(day_key, 86400)
        await pipe.execute()
    
    async def get_remaining(self, user_id: str, tier: str = "free") -> dict:
        """Get remaining requests for user."""
        limits = {
            "free": {"requests_per_minute": 10, "requests_per_day": 100},
            "premium": {"requests_per_minute": 60, "requests_per_day": 1000},
            "enterprise": {"requests_per_minute": 120, "requests_per_day": 10000}
        }
        
        tier_limits = limits.get(tier, limits["free"])
        
        minute_key = f"ratelimit:{user_id}:minute"
        day_key = f"ratelimit:{user_id}:day"
        
        minute_count = await self.redis.get(minute_key) or 0
        day_count = await self.redis.get(day_key) or 0
        
        return {
            "requests_per_minute_remaining": tier_limits["requests_per_minute"] - int(minute_count),
            "requests_per_day_remaining": tier_limits["requests_per_day"] - int(day_count)
        }

rate_limiter = RateLimiter()
```

**Exit Criteria:** Rate limiter service implemented.

---

### 1.8.5 Usage Tracker Service

**Files:**
- Create: `cloud-brain/app/services/usage_tracker.py`

**Steps:**

1. **Create usage tracker service**

```python
# cloud-brain/app/services/usage_tracker.py
import redis.asyncio as redis
from datetime import datetime
from cloudbrain.app.config import settings

class UsageTracker:
    def __init__(self):
        self.redis = redis.from_url(settings.redis_url)
    
    async def record_request(self, user_id: str, model: str, input_tokens: int, output_tokens: int):
        """Record a request for usage tracking."""
        now = datetime.utcnow()
        date_key = now.strftime("%Y-%m-%d")
        
        requests_key = f"usage:{user_id}:{date_key}:requests"
        tokens_in_key = f"usage:{user_id}:{date_key}:tokens_in"
        tokens_out_key = f"usage:{user_id}:{date_key}:tokens_out"
        cost_key = f"usage:{user_id}:{date_key}:cost"
        
        model_prices = {
            "moonshot/kimi-k2.5": {"input": 0.15, "output": 0.15},
            "anthropic/claude-3.5-sonnet": {"input": 3.0, "output": 15.0},
            "openai/gpt-4o": {"input": 2.5, "output": 10.0},
        }
        
        price = model_prices.get(model, {"input": 1.0, "output": 1.0})
        cost = (input_tokens / 1_000_000 * price["input"]) + (output_tokens / 1_000_000 * price["output"])
        
        pipe = self.redis.pipeline()
        pipe.incr(requests_key)
        pipe.incrby(tokens_in_key, input_tokens)
        pipe.incrby(tokens_out_key, output_tokens)
        pipe.incrbyfloat(cost_key, cost)
        pipe.expire(requests_key, 86400 * 30)
        pipe.expire(tokens_in_key, 86400 * 30)
        pipe.expire(tokens_out_key, 86400 * 30)
        pipe.expire(cost_key, 86400 * 30)
        await pipe.execute()
    
    async def get_daily_usage(self, user_id: str) -> dict:
        """Get today's usage for user."""
        date_key = datetime.utcnow().strftime("%Y-%m-%d")
        
        requests = await self.redis.get(f"usage:{user_id}:{date_key}:requests") or 0
        tokens_in = await self.redis.get(f"usage:{user_id}:{date_key}:tokens_in") or 0
        tokens_out = await self.redis.get(f"usage:{user_id}:{date_key}:tokens_out") or 0
        cost = await self.redis.get(f"usage:{user_id}:{date_key}:cost") or 0.0
        
        return {
            "requests": int(requests),
            "tokens_in": int(tokens_in),
            "tokens_out": int(tokens_out),
            "total_tokens": int(tokens_in) + int(tokens_out),
            "cost": float(cost)
        }
    
    async def check_budget(self, user_id: str, tier: str, estimated_cost: float) -> bool:
        """Check if user has budget for request."""
        daily_usage = await self.get_daily_usage(user_id)
        
        budgets = {
            "free": 0.50,
            "premium": 10.00,
            "enterprise": 100.00
        }
        
        budget = budgets.get(tier, budgets["free"])
        
        if daily_usage["cost"] + estimated_cost > budget:
            if daily_usage["cost"] / budget >= 0.8:
                await self.send_budget_alert(user_id, daily_usage["cost"], budget)
            return False
        
        return True
    
    async def send_budget_alert(self, user_id: str, current: float, limit: float):
        """Send budget warning alert."""
        pass

usage_tracker = UsageTracker()
```

**Exit Criteria:** Usage tracker service implemented.

---

### 1.8.6 Rate Limiter Middleware

**Files:**
- Modify: `cloud-brain/app/main.py`

**Steps:**

1. **Add rate limiter middleware**

```python
# cloud-brain/app/main.py
from fastapi import FastAPI, Request
from slowapi import Limiter
from slowapi.util import get_remote_address
from slowapi.errors import RateLimitExceeded

limiter = Limiter(key_func=get_remote_address)

app = FastAPI(title="Life Logger Cloud Brain")
app.state.limiter = limiter

@app.exception_handler(RateLimitExceeded)
async def rate_limit_handler(request: Request, exc: RateLimitExceeded):
    return JSONResponse(
        status_code=429,
        content={"detail": "Rate limit exceeded", "retry_after": exc.detail}
    )
```

**Exit Criteria:** Rate limiter middleware configured.

---

## Phase 1.9: Chat & Communication Layer

**Goal:** Implement WebSocket streaming for real-time chat and message persistence.

**Depends On:** Phase 1.8 (AI Brain)  
**Estimated Duration:** 4-5 days

### 1.9.1 WebSocket Endpoint

**Files:**
- Modify: `cloud-brain/app/api/v1/chat.py`

**Steps:**

1. **Create WebSocket chat endpoint**

```python
from fastapi import WebSocket, WebSocketDisconnect

@router.websocket("/ws/chat")
async def websocket_chat(websocket: WebSocket):
    await websocket.accept()
    
    try:
        while True:
            data = await websocket.receive_json()
            user_id = data.get("user_id")
            message = data.get("message")
            
            # Process message through orchestrator
            response = await orchestrator.process_message(user_id, message)
            
            # Stream response back
            await websocket.send_json({
                "type": "message",
                "content": response
            })
    except WebSocketDisconnect:
        pass
```

**Exit Criteria:** WebSocket endpoint accepts connections and processes messages.

---

### 1.9.2 Edge Agent WebSocket Client

**Files:**
- Modify: `life_logger/lib/core/network/ws_client.dart`

**Steps:**

1. **Update WebSocket client**

```dart
class WsClient {
  WebSocketChannel? _channel;
  
  void connect(String token) {
    _channel = WebSocketChannel.connect(
      Uri.parse('ws://10.0.2.2:8000/ws/chat?token=$token'),
    );
  }
  
  void sendMessage(String message) {
    _channel?.sink.add(jsonEncode({
      'message': message,
    }));
  }
  
  Stream<String> get messages => _channel!.stream
      .map((event) => jsonDecode(event.toString())['content']);
  
  void disconnect() {
    _channel?.sink.close();
  }
}
```

**Exit Criteria:** WebSocket client can connect, send, and receive messages.

---

### 1.9.3 Message Persistence

**Files:**
- Create: `cloud-brain/app/models/conversation.py`

**Steps:**

1. **Create conversation models**

```python
class Conversation(Base):
    __tablename__ = "conversations"
    
    id = Column(String, primary_key=True)
    user_id = Column(String, index=True)
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Message(Base):
    __tablename__ = "messages"
    
    id = Column(String, primary_key=True)
    conversation_id = Column(String, index=True)
    role = Column(String)  # 'user' or 'assistant'
    content = Column(Text)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
```

**Exit Criteria:** Conversation and message models created.

---

### 1.9.4 Edge Agent Chat Repository

**Files:**
- Create: `life_logger/lib/features/chat/data/chat_repository.dart`

**Steps:**

1. **Create chat repository**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/ws_client.dart';
import '../../../core/storage/local_db.dart';

class ChatRepository {
  final ApiClient _apiClient;
  final WsClient _wsClient;
  final LocalDb _localDb;
  
  ChatRepository({
    required ApiClient apiClient,
    required WsClient wsClient,
    required LocalDb localDb,
  }) : _apiClient = apiClient,
       _wsClient = wsClient,
       _localDb = localDb;
  
  void connectWebSocket(String token) {
    _wsClient.connect(token);
  }
  
  Stream<String> get messages => _wsClient.messages;
  
  void sendMessage(String message) {
    _wsClient.sendMessage(message);
  }
  
  Future<void> saveMessage(String role, String content) async {
    await _localDb.insertMessage(MessagesCompanion.insert(
      content: content,
      role: role,
      createdAt: DateTime.now(),
    ));
  }
}
```

**Exit Criteria:** Chat repository compiles, handles WebSocket and local storage.

---

### 1.9.5 Chat UI in Harness

**Files:**
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Add simple chat UI to harness**

```dart
// Simple chat display in harness
ListView(
  children: [
    Text('User: ${_chatInputController.text}'),
    Text('AI: ${_outputController.text}'),
  ],
)
```

**Exit Criteria:** Harness shows chat messages.

---

### 1.9.6 Push Notifications (FCM)

**Files:**
- Create: `cloud-brain/app/services/push_service.py`

**Steps:**

1. **Create push service**

```python
from firebase_admin import messaging

class PushService:
    def __init__(self):
        # Initialize Firebase Admin SDK
        pass
    
    def send_notification(self, token: str, title: str, body: str):
        message = messaging.Message(
            notification=messaging.Notification(
                title=title,
                body=body,
            ),
            token=token,
        )
        return messaging.send(message)
```

**Exit Criteria:** Push service compiles.

---

### 1.9.7 Edge Agent FCM Setup

**Files:**
- Create: `life_logger/lib/core/network/fcm_service.dart`

**Steps:**

1. **Create FCM service**

```dart
import 'package:firebase_messaging/firebase_messaging.dart';

class FCMService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  
  Future<String?> getToken() async {
    return await _messaging.getToken();
  }
  
  void onBackgroundMessage(handler) {
    FirebaseMessaging.onBackgroundMessage(handler);
  }
}
```

**Exit Criteria:** FCM service compiles.

---

**Phase 1.9 Exit Criteria:**
- [ ] WebSocket endpoint implemented
- [ ] Edge Agent WebSocket client works
- [ ] Message persistence models created
- [ ] Chat repository implemented
- [ ] Chat UI in harness
- [ ] Push notification service
- [ ] Edge Agent FCM setup

---

## Phase 1.10: Background Services & Sync Engine

**Goal:** Implement background data sync and push-to-write flow.

**Depends On:** Phase 1.4, 1.5, 1.9  
**Estimated Duration:** 4-5 days

### 1.10.1 Cloud-to-Device Write Flow

**Files:**
- Modify: `cloud-brain/app/agent/orchestrator.py`

**Steps:**

1. **Implement write flow**

```python
async def handle_write_request(self, user_id: str, data_type: str, value: dict) -> dict:
    """Handle request to write to Health Store."""
    
    # 1. Determine target platform (iOS/Android)
    # 2. Generate FCM payload
    payload = {
        "action": "write_health",
        "data_type": data_type,
        "value": value,
    }
    
    # 3. Send via FCM to user's device
    user_fcm_token = await self._get_user_fcm_token(user_id)
    if user_fcm_token:
        await push_service.send_notification(
            token=user_fcm_token,
            title="Life Logger",
            body=f"Writing {data_type} to Health...",
            data=payload
        )
    
    return {"success": True, "message": "Write queued"}
```

**Exit Criteria:** Write requests generate FCM payloads.

---

### 1.10.2 Background Sync Scheduler

**Files:**
- Create: `cloud-brain/app/services/sync_scheduler.py`

**Steps:**

1. **Create sync scheduler**

```python
from celery import Celery

celery_app = Celery("life_logger", broker=settings.redis_url)

@celery_app.task
def sync_user_data(user_id: str):
    """Periodic task to sync user data."""
    # 1. Fetch latest data from all integrations
    # 2. Update Pinecone context
    # 3. Check for anomalies
    pass

@celery_app.task
def refresh_integration_tokens():
    """Refresh OAuth tokens for all users."""
    pass

# Schedule: sync every 15 minutes
celery_app.conf.beat_schedule = {
    'sync-every-15-minutes': {
        'task': 'sync_user_data',
        'schedule': 900.0,
    },
}
```

**Exit Criteria:** Celery tasks defined and scheduled.

---

### 1.10.3 Edge Agent Background Handler

**Files:**
- Modify: `life_logger/lib/core/network/fcm_service.dart`

**Steps:**

1. **Handle background messages**

```dart
void setupBackgroundHandler() {
  FirebaseMessaging.onBackgroundMessage((message) async {
    final data = message.data;
    
    if (data['action'] == 'write_health') {
      final dataType = data['data_type'];
      final value = data['value'];
      
      final healthRepo = HealthRepository();
      
      if (dataType == 'nutrition') {
        await healthRepo.writeNutrition(
          calories: value['calories'],
          date: DateTime.parse(value['date']),
        );
      }
    }
    
    return;
  });
}
```

**Exit Criteria:** Background handler can process write requests.

---

### 1.10.4 Data Normalization

**Files:**
- Create: `cloud-brain/app/analytics/normalizer.py`

**Steps:**

1. **Create normalizer**

```python
class DataNormalizer:
    """Normalize data from different sources to common format."""
    
    @staticmethod
    def normalize_activity(source: str, data: dict) -> dict:
        """Normalize activity data to common format."""
        
        if source == "strava":
            return {
                "type": data.get("type", "Unknown"),
                "distance_meters": data.get("distance", 0),
                "duration_seconds": data.get("moving_time", 0),
                "calories": data.get("calories", 0),
                "start_time": data.get("start_date_local"),
            }
        
        elif source == "apple_health":
            return {
                "type": data.get("workoutActivityType", "Unknown"),
                "distance_meters": data.get("distance", 0),
                "duration_seconds": data.get("duration", 0),
                "calories": data.get("energyBurned", 0),
                "start_time": data.get("startDate"),
            }
        
        return data
```

**Exit Criteria:** Data normalizer compiles.

---

### 1.10.5 Source-of-Truth Hierarchy

**Files:**
- Create: `cloud-brain/app/analytics/deduplication.py`

**Steps:**

1. **Create deduplication logic**

```python
class SourceOfTruth:
    """Determine which source takes precedence for overlapping data."""
    
    PRIORITY = {
        "apple_health": 10,
        "health_connect": 10,
        "strava": 8,
        "fitbit": 6,
        "oura": 5,
    }
    
    @staticmethod
    def resolve_conflicts(data_points: list[dict]) -> dict:
        """When multiple sources have the same data, pick the best."""
        
        if not data_points:
            return {}
        
        # Sort by source priority
        sorted_data = sorted(
            data_points,
            key=lambda x: SourceOfTruth.PRIORITY.get(x.get("source"), 0),
            reverse=True
        )
        
        # Return highest priority
        return sorted_data[0]
```

**Exit Criteria:** Deduplication logic compiles.

---

### 1.10.6 Sync Status Tracking

**Files:**
- Modify: `cloud-brain/app/models/integration.py`

**Steps:**

1. **Add sync tracking**

```python
# In Integration model
last_synced_at = Column(DateTime(timezone=True))
sync_status = Column(String, default="idle")  # idle, syncing, error
sync_error = Column(String, nullable=True)
```

**Exit Criteria:** Integration model tracks sync status.

---

### 1.10.7 Harness: Background Sync Test

**Files:**
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Add sync test buttons**

```dart
ElevatedButton(
  onPressed: () {
    _outputController.text = 'Syncing...';
    // Trigger background sync
  },
  child: const Text('Trigger Sync'),
),

ElevatedButton(
  onPressed: () {
    _outputController.text = 'Checking sync status...';
    // Check last sync time
  },
  child: const Text('Check Sync Status'),
),
```

**Exit Criteria:** Harness can trigger and check sync status.

---

**Phase 1.10 Exit Criteria:**
- [ ] Cloud-to-device write flow implemented
- [ ] Celery sync scheduler created
- [ ] Edge Agent background handler processes FCM
- [ ] Data normalizer for cross-source data
- [ ] Source-of-truth deduplication
- [ ] Sync status tracking in database
- [ ] Harness can trigger sync

---

## Phase 1.11: Analytics & Cross-App Reasoning

**Goal:** Implement analytics engine that powers the "Cross-App AI Reasoning" feature.

**Depends On:** Phase 1.8 (AI Brain), Phase 1.10 (Sync Engine)  
**Estimated Duration:** 4-5 days

### 1.11.1 Analytics Dashboard Data

**Files:**
- Create: `cloud-brain/app/api/v1/analytics.py`

**Steps:**

1. **Create analytics endpoints**

```python
@router.get("/analytics/daily-summary")
async def get_daily_summary(user_id: str, date: str = None):
    """Get daily summary for dashboard."""
    # Aggregate data from all sources
    return {
        "date": date or date.today().isoformat(),
        "steps": 8500,
        "calories_consumed": 1850,
        "calories_burned": 450,
        "workouts": 1,
        "sleep_hours": 7.5,
    }

@router.get("/analytics/weekly-trends")
async def get_weekly_trends(user_id: str):
    """Get weekly trend data."""
    return {
        "steps": [8500, 9200, 7800, 10500, 8900, 6500, 8100],
        "calories": [1800, 1950, 2100, 1850, 1750, 2200, 1900],
        "workouts": [1, 1, 0, 2, 1, 0, 1],
    }
```

**Exit Criteria:** Analytics endpoints return dashboard data.

---

### 1.11.2 Correlation Analysis

**Files:**
- Modify: `cloud-brain/app/analytics/reasoning_engine.py`

**Steps:**

1. **Add correlation analysis**

```python
import numpy as np

class ReasoningEngine:
    def calculate_correlation(self, x: list, y: list) -> float:
        """Calculate Pearson correlation between two metrics."""
        if len(x) != len(y) or len(x) < 3:
            return 0.0
        
        return np.corrcoef(x, y)[0, 1]
    
    def analyze_sleep_activity_correlation(
        self,
        sleep_data: list[dict],
        activity_data: list[dict]
    ) -> dict:
        """Analyze how sleep affects activity."""
        
        # Match by date
        # Calculate correlation
        correlation = self.calculate_correlation(
            [s.get("hours", 0) for s in sleep_data],
            [a.get("calories_burned", 0) for a in activity_data]
        )
        
        return {
            "correlation": correlation,
            "insight": self._interpret_correlation(correlation)
        }
```

**Exit Criteria:** Correlation analysis compiles.

---

### 1.11.3 Trend Detection

**Files:**
- Modify: `cloud-brain/app/analytics/reasoning_engine.py`

**Steps:**

1. **Add trend detection**

```python
def detect_trends(self, data: list[dict], metric: str, window: int = 7) -> dict:
    """Detect trends in a metric."""
    
    values = [d.get(metric, 0) for d in data]
    
    if len(values) < window:
        return {"trend": "insufficient_data"}
    
    recent_avg = sum(values[-window:]) / window
    previous_avg = sum(values[-window*2:-window]) / window
    
    change_pct = ((recent_avg - previous_avg) / previous_avg) * 100 if previous_avg else 0
    
    return {
        "recent_average": recent_avg,
        "previous_average": previous_avg,
        "change_percent": change_pct,
        "trend": "up" if change_pct > 10 else "down" if change_pct < -10 else "stable",
    }
```

**Exit Criteria:** Trend detection compiles.

---

### 1.11.4 Goal Tracking

**Files:**
- Create: `cloud-brain/app/analytics/goal_tracker.py`

**Steps:**

1. **Create goal tracker**

```python
class GoalTracker:
    def __init__(self, db):
        self.db = db
    
    async def check_goals(self, user_id: str, data: dict) -> list[dict]:
        """Check user's goals against current data."""
        
        user_goals = await self._get_user_goals(user_id)
        results = []
        
        for goal in user_goals:
            if goal["type"] == "daily_steps":
                current = data.get("steps", 0)
                target = goal["target"]
                results.append({
                    "goal": "daily_steps",
                    "current": current,
                    "target": target,
                    "progress": min(100, (current / target) * 100),
                    "achieved": current >= target
                })
        
        return results
```

**Exit Criteria:** Goal tracker compiles.

---

### 1.11.5 Insight Generation

**Files:**
- Modify: `cloud-brain/app/analytics/reasoning_engine.py`

**Steps:**

1. **Add insight generation**

```python
def generate_insight(
    self,
    user_id: str,
    daily_data: dict,
    weekly_trends: dict,
    goals: list[dict]
) -> str:
    """Generate a single insight card for the dashboard."""
    
    # Priority 1: Goal progress
    for goal in goals:
        if not goal["achieved"] and goal["progress"] > 80:
            return f"You're {100 - goal['progress']:.0f}% away from your {goal['goal']} goal. Almost there!"
    
    # Priority 2: Negative trends
    if weekly_trends.get("steps", {}).get("trend") == "down":
        return "Your steps have dropped this week. Time to get moving!"
    
    # Priority 3: Positive correlation
    if weekly_trends.get("sleep_hours", 0) > 7:
        return "Great sleep lately! You're crushing your workouts."
    
    return "Keep up the good work!"
```

**Exit Criteria:** Insight generation compiles.

---

### 1.11.6 Edge Agent Analytics Repository

**Files:**
- Create: `life_logger/lib/features/analytics/data/analytics_repository.dart`

**Steps:**

1. **Create analytics repository**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/network/api_client.dart';

class AnalyticsRepository {
  final ApiClient _apiClient;
  
  AnalyticsRepository({required ApiClient apiClient}) : _apiClient = apiClient;
  
  Future<Map<String, dynamic>> getDailySummary(DateTime date) async {
    final response = await _apiClient.get('/analytics/daily-summary', queryParameters: {
      'date': date.toIso8601String(),
    });
    return response.data;
  }
  
  Future<Map<String, dynamic>> getWeeklyTrends() async {
    final response = await _apiClient.get('/analytics/weekly-trends');
    return response.data;
  }
}
```

**Exit Criteria:** Analytics repository compiles.

---

### 1.11.7 Harness: Analytics Test

**Files:**
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Add analytics test buttons**

```dart
ElevatedButton(
  onPressed: () async {
    final analytics = ref.read(analyticsRepositoryProvider);
    final summary = await analytics.getDailySummary(DateTime.now());
    _outputController.text = 'Today: ${summary['steps']} steps, ${summary['calories_consumed']} cal';
  },
  child: const Text('Get Daily Summary'),
),

ElevatedButton(
  onPressed: () async {
    final analytics = ref.read(analyticsRepositoryProvider);
    final trends = await analytics.getWeeklyTrends();
    _outputController.text = 'Weekly: ${trends['steps']}';
  },
  child: const Text('Get Weekly Trends'),
),
```

**Exit Criteria:** Harness can fetch and display analytics data.

---

**Phase 1.11 Exit Criteria:**
- [ ] Analytics endpoints implemented
- [ ] Correlation analysis compiles
- [ ] Trend detection compiles
- [ ] Goal tracking compiles
- [ ] Insight generation compiles
- [ ] Edge Agent analytics repository
- [ ] Harness can fetch analytics

---

## Phase 1.12: Autonomous Actions & Deep Linking

**Goal:** Implement the "Autonomous Task Execution" feature — deep links to open external apps.

**Depends On:** Phase 1.6 (Strava), Phase 1.7 (CalAI), Phase 1.8 (AI Brain)  
**Estimated Duration:** 3-4 days

### 1.12.1 Deep Link MCP Tools

**Files:**
- Modify: `cloud-brain/app/agent/orchestrator.py`

**Steps:**

1. **Add deep link tools to MCP**

```python
class DeepLinkServer(BaseMCPServer):
    """MCP server for deep linking to external apps."""
    
    def get_tools(self) -> list[dict]:
        return [
            {
                "name": "open_app",
                "description": "Open an external app via deep link",
                "input_schema": {
                    "type": "object",
                    "properties": {
                        "app": {"type": "string", "enum": ["strava", "calai", "myfitnesspal"]},
                        "action": {"type": "string", "enum": ["record", "camera", "home"]},
                    },
                    "required": ["app"]
                }
            }
        ]
    
    async def execute_tool(self, tool_name: str, params: dict, user_id: str) -> dict:
        # Return deep link URL for Edge Agent to open
        app = params.get("app")
        action = params.get("action", "home")
        
        deep_links = {
            ("strava", "record"): "strava://record?sport=running",
            ("strava", "home"): "strava://",
            ("calai", "camera"): "calai://camera",
            ("calai", "home"): "calai://",
            ("myfitnesspal", "home"): "mfp://",
        }
        
        uri = deep_links.get((app, action), f"{app}://")
        
        return {
            "success": True,
            "data": {
                "deep_link": uri,
                "message": f"Opening {app}..."
            }
        }
```

**Exit Criteria:** Deep link MCP server compiles.

---

### 1.12.2 Edge Agent Deep Link Executor

**Files:**
- Modify: `life_logger/lib/core/deeplink/deeplink_launcher.dart`

**Steps:**

1. **Add execute method**

```dart
class DeepLinkLauncher {
  static Future<bool> executeDeepLink(String deepLink) async {
    final uri = Uri.parse(deepLink);
    
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    
    // If app not installed, open web fallback
    final webFallback = _getWebFallback(deepLink);
    if (webFallback != null) {
      return await launchUrl(Uri.parse(webFallback), mode: LaunchMode.externalApplication);
    }
    
    return false;
  }
  
  static String? _getWebFallback(String deepLink) {
    if (deepLink.startsWith('strava://')) {
      return 'https://www.strava.com/dashboard';
    }
    if (deepLink.startsWith('calai://')) {
      return 'https://calai.com/app';
    }
    return null;
  }
}
```

**Exit Criteria:** Deep link executor compiles.

---

### 1.12.3 Autonomous Action Response Format

**Files:**
- Modify: `cloud-brain/app/agent/orchestrator.py`

**Steps:**

1. **Return action in response**

```python
# When LLM determines an action is needed:
response = {
    "message": "Opening Strava for you. Tap Start when ready!",
    "action": {
        "type": "deep_link",
        "uri": "strava://record?sport=running"
    }
}
```

**Exit Criteria:** Responses can include action payloads.

---

### 1.12.4 Harness: Deep Link Test

**Files:**
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Add deep link test**

```dart
ElevatedButton(
  onPressed: () async {
    final success = await DeepLinkLauncher.executeDeepLink('strava://record');
    _outputController.text = success ? 'Opened Strava' : 'Failed to open';
  },
  child: const Text('Test Deep Link'),
),
```

**Exit Criteria:** Harness can test deep links.

---

### 1.12.5 Integration Document

**Files:**
- Create: `docs/plans/integrations/deep-links-integration.md`

**Steps:**

1. **Create integration document** with:
   - All supported deep link URIs
   - Platform-specific behavior
   - Fallback strategies

**Exit Criteria:** Integration document created.

---

**Phase 1.12 Exit Criteria:**
- [ ] Deep link MCP server compiles
- [ ] Edge Agent can execute deep links
- [ ] Response format includes actions
- [ ] Harness can test deep links
- [ ] Integration document created

---

## Phase 1.13: Subscription & Monetization

**Goal:** Implement subscription tier enforcement and RevenueCat integration.

**Depends On:** Phase 1.2 (Auth)  
**Estimated Duration:** 3-4 days

### 1.13.1 Subscription Models

**Files:**
- Modify: `cloud-brain/app/models/user.py`

**Steps:**

1. **Add subscription fields**

```python
# In User model
is_premium = Column(Boolean, default=False)
subscription_tier = Column(String, default="free")  # free, pro
subscription_expires_at = Column(DateTime(timezone=True))
revenuecat_customer_id = Column(String)
```

**Exit Criteria:** User model tracks subscription.

---

### 1.13.2 Tier Middleware

**Files:**
- Create: `cloud-brain/app/services/subscription.py`

**Steps:**

1. **Create subscription service**

```python
from functools import wraps
from fastapi import HTTPException, status

TIER_LIMITS = {
    "free": {
        "daily_messages": 10,
        "integrations": 2,
        "ai_actions": False,
    },
    "pro": {
        "daily_messages": float("inf"),
        "integrations": float("inf"),
        "ai_actions": True,
    }
}

def check_tier(required_tier: str = "free"):
    """Decorator to enforce subscription tier."""
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            user_id = kwargs.get("user_id")
            user = await get_user(user_id)
            
            if user.subscription_tier == "free":
                limits = TIER_LIMITS["free"]
                if required_tier == "pro":
                    if not limits.get("ai_actions"):
                        raise HTTPException(
                            status_code=status.HTTP_402_PAYMENT_REQUIRED,
                            detail="Upgrade to Pro for this feature"
                        )
            
            return await func(*args, **kwargs)
        return wrapper
    return decorator
```

**Exit Criteria:** Tier middleware compiles.

---

### 1.13.3 RevenueCat Webhook Handler

**Files:**
- Create: `cloud-brain/app/api/v1/webhooks.py`

**Steps:**

1. **Create webhook endpoint**

```python
@router.post("/webhooks/revenuecat")
async def revenuecat_webhook(request: Request):
    """Handle RevenueCat subscription events."""
    payload = await request.json()
    event = payload.get("event")
    
    if event == "subscription_created" or event == "subscription_renewed":
        user_id = payload.get("app_user_id")
        await update_user_subscription(user_id, tier="pro")
    
    elif event == "subscription_cancelled":
        user_id = payload.get("app_user_id")
        await update_user_subscription(user_id, tier="free")
    
    return {"received": True}
```

**Exit Criteria:** Webhook endpoint compiles.

---

### 1.13.4 Edge Agent Subscription Check

**Files:**
- Create: `life_logger/lib/features/subscription/data/subscription_repository.dart`

**Steps:**

1. **Create subscription repository**

```dart
class SubscriptionRepository {
  final ApiClient _apiClient;
  
  SubscriptionRepository({required ApiClient apiClient}) : _apiClient = apiClient;
  
  Future<String> getSubscriptionTier() async {
    final response = await _apiClient.get('/user/subscription');
    return response.data['tier'] ?? 'free';
  }
  
  Future<bool> canUseFeature(String feature) async {
    final tier = await getSubscriptionTier();
    if (tier == 'pro') return true;
    
    // Check free tier limits
    // Return true/false based on feature
    return false;
  }
}
```

**Exit Criteria:** Subscription repository compiles.

---

### 1.13.5 Paywall UI in Harness

**Files:**
- Modify: `life_logger/lib/features/harness/harness_screen.dart`

**Steps:**

1. **Add subscription test**

```dart
ElevatedButton(
  onPressed: () async {
    final subRepo = ref.read(subscriptionRepositoryProvider);
    final tier = await subRepo.getSubscriptionTier();
    _outputController.text = 'Current tier: $tier';
  },
  child: const Text('Check Subscription'),
),
```

**Exit Criteria:** Harness can check subscription tier.

---

**Phase 1.13 Exit Criteria:**
- [ ] User model tracks subscription
- [ ] Tier middleware enforces limits
- [ ] RevenueCat webhook handler
- [ ] Edge Agent subscription repository
- [ ] Harness can check subscription

---

## Phase 1.14: End-to-End Testing & Exit Criteria

**Goal:** Verify the complete MVP works end-to-end and document exit criteria.

**Depends On:** All previous phases  
**Estimated Duration:** 3-4 days

### 1.14.1 Integration Tests

**Files:**
- Create: `cloud-brain/tests/integration/test_full_flow.py`

**Steps:**

1. **Write integration tests**

```python
import pytest
from httpx import AsyncClient
from cloudbrain.app.main import app

@pytest.mark.asyncio
async def test_full_user_flow():
    """Test: Register -> Connect Strava -> Query AI -> Get response."""
    
    # 1. Register user
    async with AsyncClient(app=app, base_url="http://test") as client:
        register_resp = await client.post("/auth/register", json={
            "email": "test@example.com",
            "password": "testpass123"
        })
        assert register_resp.status_code == 200
    
    # 2. Login
    login_resp = await client.post("/auth/login", json={
        "email": "test@example.com",
        "password": "testpass123"
    })
    token = login_resp.json()["session"]["access_token"]
    
    # 3. Query AI
    chat_resp = await client.post("/chat", json={
        "message": "How many steps did I take today?"
    }, headers={"Authorization": f"Bearer {token}"})
    
    assert chat_resp.status_code == 200
    assert "response" in chat_resp.json()
```

**Exit Criteria:** Integration tests pass.

---

### 1.14.2 E2E Flutter Test

**Files:**
- Create: `life_logger/test/e2e/harness_test.dart`

**Steps:**

1. **Write widget test**

```dart
testWidgets('Harness shows login and health buttons', (WidgetTester tester) async {
  await tester.pumpWidget(
    const ProviderScope(child: LifeLoggerApp()),
  );
  
  expect(find.text('TEST HARNESS - NO STYLING'), findsOneWidget);
  expect(find.text('1. Login'), findsOneWidget);
  expect(find.text('4. Read HealthKit'), findsOneWidget);
});
```

**Exit Criteria:** Flutter tests pass.

---

### 1.14.3 Documentation

**Files:**
- Modify**Doc:** [Backend Implementation Plan](./backend-implementation.md)` (this document)

**Steps:**

1. **Mark all exit criteria as complete**

**Exit Criteria:** Documentation complete.

---

### 1.14.4 Code Review

**Steps:**

1. **Review all code for:**
   - Security (no exposed secrets)
   - Error handling
   - Type safety
   - Test coverage

**Exit Criteria:** Code review passed.

---

### 1.14.5 Performance Testing

**Steps:**

1. **Test:**
   - API response times
   - WebSocket latency
   - Database query performance

**Exit Criteria:** Performance acceptable.

---

### 1.14.6 Final Exit Criteria Checklist

**MVP Exit Criteria:**
- [ ] User can register and login
- [ ] User can connect Strava via OAuth
- [ ] User can read activities from Strava
- [ ] User can write activities to Strava
- [ ] User can request HealthKit authorization
- [ ] User can read steps from Apple Health
- [ ] User can read workouts from Apple Health
- [ ] User can write nutrition to Apple Health
- [ ] User can read/write to Google Health Connect
- [ ] AI can answer health questions
- [ ] AI can analyze cross-app data
- [ ] Deep links can open Strava
- [ ] Subscription tiers enforced
- [ ] Test harness fully functional

---

## Post-MVP Integrations (Deferred)

The following integrations are **NOT in MVP scope** but are documented for future phases:

| Integration  | Priority | Reference File                                                |
| ------------ | -------- | ------------------------------------------------------------- |
| Fitbit       | P1       | `docs/plans/integrations/fitbit-integration.md` (to be created) |
| Oura Ring    | P1       | `docs/plans/integrations/oura-integration.md` (to be created)   |
| WHOOP        | P2       | `docs/plans/integrations/whoop-integration.md` (to be created)  |
| Garmin       | P2       | `docs/plans/integrations/garmin-integration.md` (to be created) |
| MyFitnessPal | Implicit | Via deep links + Health Stores                                |

---

**End of Backend Implementation Plan**
