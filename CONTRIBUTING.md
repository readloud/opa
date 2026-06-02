# Contributing to Oil Palm Assistant (OPA)

First off, thank you for considering contributing to OPA! It's people like you that make OPA a great tool for the palm oil industry.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [Getting Started](#getting-started)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Testing Requirements](#testing-requirements)
- [Documentation](#documentation)
- [Community](#community)

## 📜 Code of Conduct

### Our Pledge

In the interest of fostering an open and welcoming environment, we as contributors and maintainers pledge to make participation in our project and our community a harassment-free experience for everyone, regardless of age, body size, disability, ethnicity, gender identity and expression, level of experience, nationality, personal appearance, race, religion, or sexual identity and orientation.

### Our Standards

Examples of behavior that contributes to creating a positive environment include:

- Using welcoming and inclusive language
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

Examples of unacceptable behavior include:

- The use of sexualized language or imagery and unwelcome sexual attention or advances
- Trolling, insulting/derogatory comments, and personal or political attacks
- Public or private harassment
- Publishing others' private information without explicit permission
- Other conduct which could reasonably be considered inappropriate in a professional setting

### Enforcement

Instances of abusive, harassing, or otherwise unacceptable behavior may be reported by contacting the project team at **conduct@opa-app.com**. All complaints will be reviewed and investigated and will result in a response that is deemed necessary and appropriate to the circumstances.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.16+)
- Node.js (18+)
- PostgreSQL (15+ with PostGIS)
- Git
- Docker (optional)

### Setting Up Development Environment

```bash
# Fork the repository
# Then clone your fork
git clone https://github.com/readloud/opa.git
cd opa

# Add upstream remote
git remote add upstream https://github.com/original-org/opa.git

# Install backend dependencies
cd backend
npm install

# Install frontend dependencies
cd ../frontend
flutter pub get

# Setup database
cd ../backend
npx prisma generate
npx prisma migrate dev

# Run development servers
# Terminal 1 (Backend)
npm run start:dev

# Terminal 2 (Frontend)
cd ../frontend
flutter run
```

## 💡 How Can I Contribute?

### Types of Contributions

#### 🐛 Bug Reports

- **Ensure the bug was not already reported** by searching on GitHub under [Issues](https://github.com/readloud/opa/issues)
- If you're unable to find an open issue addressing the problem, [open a new one](https://github.com/readloud/opa/issues/new)
- Use the provided bug report template

#### ✨ Feature Requests

- Open a new issue with the **feature request** template
- Clearly describe the feature and its use case
- Include mockups or examples if possible

#### 📝 Documentation

- Fix typos, improve clarity, add examples
- Translate documentation to other languages
- Add JSDoc/ Dartdoc comments to code

#### 🧪 Tests

- Write unit tests for new features
- Improve test coverage
- Write integration tests for critical paths

#### 💻 Code Contributions

- Fix bugs
- Implement features
- Refactor code for better performance/maintainability

### Issue Labels

| Label | Description |
|-------|-------------|
| `bug` | Something isn't working |
| `enhancement` | New feature or request |
| `documentation` | Improvements or additions to documentation |
| `good-first-issue` | Good for newcomers |
| `help-wanted` | Extra attention is needed |
| `question` | Further information is requested |
| `wontfix` | This will not be worked on |

## 🔄 Development Workflow

### Branch Naming Convention

```
feature/description     - New features
bugfix/description      - Bug fixes
hotfix/description      - Critical production fixes
docs/description        - Documentation updates
test/description        - Testing additions
refactor/description    - Code refactoring
chore/description       - Maintenance tasks
```

### Example Branch Names

```bash
feature/pest-detection-ai
bugfix/offline-sync-crash
hotfix/login-otp-timeout
docs/api-documentation
test/integration-harvest
refactor/state-management
chore/update-dependencies
```

### Development Process

1. **Synchronize** with upstream:

```bash
git checkout main
git pull upstream main
git push origin main
```

2. **Create branch** for your work:

```bash
git checkout -b feature/your-feature-name
```

3. **Make changes** with proper commits

4. **Run tests** locally:

```bash
# Backend
cd backend
npm run test
npm run lint

# Frontend
cd frontend
flutter test
flutter analyze
```

5. **Push** your branch:

```bash
git push origin feature/your-feature-name
```

6. **Create Pull Request** to `main` branch

## 📝 Coding Standards

### Dart/Flutter Standards

```dart
// ✅ Good: Proper naming conventions
class HarvestService {
  final Dio _dio;
  String? _cachedToken;
  
  Future<Harvest> createHarvest(CreateHarvestDto dto) async {
    // Implementation
  }
}

// ❌ Bad
class harvest_service {
  var dio;
  String cachedToken;
  
  Future createHarvest(dto) {
    // Implementation
  }
}
```

### TypeScript/NestJS Standards

```typescript
// ✅ Good: Proper typing and decorators
@Injectable()
export class HarvestService {
  constructor(
    @InjectRepository(Harvest)
    private harvestRepository: Repository<Harvest>,
  ) {}
  
  async createHarvest(dto: CreateHarvestDto): Promise<Harvest> {
    return this.harvestRepository.save(dto);
  }
}

// ❌ Bad
class HarvestService {
  constructor(harvestRepository) {
    this.harvestRepository = harvestRepository;
  }
  
  async createHarvest(dto) {
    return this.harvestRepository.save(dto);
  }
}
```

### Naming Conventions

| Type | Convention | Example |
|------|------------|---------|
| Files | snake_case | `harvest_service.dart` |
| Classes | PascalCase | `HarvestService` |
| Functions | camelCase | `createHarvest()` |
| Variables | camelCase | `harvestCount` |
| Constants | SCREAMING_SNAKE_CASE | `MAX_RETRY_COUNT` |
| Private members | _prefix | `_privateMethod()` |

## 📝 Commit Guidelines

We follow **Conventional Commits** specification:

### Format

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

| Type | Description | Example |
|------|-------------|---------|
| `feat` | New feature | `feat(harvest): add batch import` |
| `fix` | Bug fix | `fix(sync): resolve offline conflict` |
| `docs` | Documentation | `docs(readme): update installation` |
| `style` | Code style | `style(flutter): format code` |
| `refactor` | Code refactor | `refactor(api): simplify error handling` |
| `test` | Testing | `test(harvest): add unit tests` |
| `chore` | Maintenance | `chore(deps): update dependencies` |

### Examples

```bash
# Feature commit
feat(ml): add pest detection from drone imagery

- Integrate TensorFlow model
- Add API endpoint for detection
- Create Flutter UI for results

# Bug fix commit
fix(chat): resolve WebSocket reconnection issue

Fixes #123

# Breaking change commit
feat(auth)!: migrate to OTP-based authentication

BREAKING CHANGE: Email/password login removed
```

## 🔄 Pull Request Process

### PR Template

```markdown
## Description
[Describe the changes you've made]

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed

## Screenshots (if applicable)
[Add screenshots here]

## Checklist
- [ ] My code follows the style guidelines
- [ ] I have performed a self-review
- [ ] I have commented my code where needed
- [ ] I have updated the documentation
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix is effective
```

### PR Requirements

- **Minimum 1 approval** from maintainers
- **All checks must pass** (CI/CD)
- **No merge conflicts** with main branch
- **Proper commit history** (no merge commits)
- **Updated documentation** if needed

### After PR Approval

- Squash and merge (preferred)
- Delete feature branch
- Close related issues

## 🧪 Testing Requirements

### Unit Tests

```dart
// Flutter example
void main() {
  group('HarvestService', () {
    test('createHarvest should save data', () async {
      final service = HarvestService();
      final result = await service.createHarvest(mockDto);
      expect(result.id, isNotNull);
    });
  });
}
```

```typescript
// NestJS example
describe('HarvestService', () => {
  it('should create harvest', async () => {
    const service = module.get<HarvestService>(HarvestService);
    const result = await service.createHarvest(mockDto);
    expect(result.id).toBeDefined();
  });
});
```

### Coverage Requirements

- **Lines**: ≥ 80%
- **Functions**: ≥ 80%
- **Branches**: ≥ 70%

### Run Tests Locally

```bash
# Backend
npm run test
npm run test:cov

# Frontend
flutter test
flutter test --coverage
```

## 📚 Documentation

### Code Documentation

```dart
/// Creates a new harvest record
/// 
/// [dto] contains the harvest data including blockId, tonase, and harvestDate
/// 
/// Returns the created [Harvest] object
/// 
/// Throws [NotFoundException] if block doesn't exist
/// Throws [ForbiddenException] if user doesn't have access
Future<Harvest> createHarvest(CreateHarvestDto dto) async {
  // Implementation
}
```

### API Documentation

Use Swagger/OpenAPI decorators:

```typescript
@ApiOperation({ summary: 'Create harvest record' })
@ApiResponse({ status: 201, description: 'Harvest created' })
@ApiResponse({ status: 404, description: 'Block not found' })
@Post()
async create(@Body() dto: CreateHarvestDto) {
  return this.harvestService.create(dto);
}
```

## 👥 Community

### Communication Channels

- **GitHub Issues**: Bug reports and feature requests
- **Discord**: Real-time chat (invite link)
- **Email**: support@opa-app.com
- **Weekly Calls**: Every Tuesday at 10 AM (GMT+7)

### Recognition

Contributors will be:
- Added to **CONTRIBUTORS.md**
- Mentioned in **release notes**
- Given **contributor role** on Discord

### First-time Contributors

Look for issues labeled `good-first-issue` or `help-wanted`. These are specifically curated for new contributors.

## 🏆 Recognition

Our top contributors will be recognized in our README and social media:

| Level | Criteria | Recognition |
|-------|----------|-------------|
| Gold | 100+ commits | Featured in README, swag package |
| Silver | 50+ commits | Mentioned in README |
| Bronze | 10+ commits | Shoutout in release notes |

---

**Thank you for contributing to OPA! 🌴**