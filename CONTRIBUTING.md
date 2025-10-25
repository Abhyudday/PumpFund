# Contributing to PumpFunds

Thank you for your interest in contributing to PumpFunds! We welcome contributions from the community.

## How to Contribute

### Reporting Bugs

1. Check if the bug has already been reported in [Issues](https://github.com/yourusername/pumpfunds/issues)
2. If not, create a new issue with:
   - Clear title and description
   - Steps to reproduce
   - Expected vs actual behavior
   - Screenshots if applicable
   - Device/OS information

### Suggesting Features

1. Check if the feature has already been suggested
2. Create a new issue with label `enhancement`
3. Clearly describe the feature and its benefits
4. Provide examples or mockups if possible

### Pull Requests

1. **Fork** the repository
2. **Clone** your fork locally
3. **Create a branch** for your feature:
   ```bash
   git checkout -b feature/YourFeatureName
   ```
4. **Make your changes** following our coding standards
5. **Test thoroughly** - ensure nothing breaks
6. **Commit** with clear, descriptive messages:
   ```bash
   git commit -m "Add feature: description of feature"
   ```
7. **Push** to your fork:
   ```bash
   git push origin feature/YourFeatureName
   ```
8. **Create a Pull Request** with:
   - Clear title and description
   - Link to related issues
   - Screenshots/videos for UI changes
   - Testing steps

## Development Setup

See [README.md](README.md) for detailed setup instructions.

## Coding Standards

### Flutter/Dart
- Follow [Effective Dart](https://dart.dev/guides/language/effective-dart) guidelines
- Use BLoC pattern for state management
- Add documentation comments for public APIs
- Run `flutter analyze` before committing
- Format code with `flutter format .`

### Node.js/JavaScript
- Use ES6+ features
- Follow [Airbnb JavaScript Style Guide](https://github.com/airbnb/javascript)
- Add JSDoc comments for functions
- Use async/await over callbacks
- Handle errors properly

### Git Commit Messages
Format:
```
<type>: <subject>

<body>

<footer>
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding/updating tests
- `chore`: Build process or tooling changes

Example:
```
feat: Add stop-loss functionality for investments

- Add stopLossPercentage field to Investment model
- Implement automatic position closure on threshold
- Add UI for configuring stop-loss
- Add tests for stop-loss logic

Closes #123
```

## Testing

### Flutter App
```bash
# Run all tests
flutter test

# Run specific test
flutter test test/wallet_service_test.dart

# Check coverage
flutter test --coverage
```

### Backend
```bash
cd backend

# Run tests (when implemented)
npm test

# Check for vulnerabilities
npm audit
```

## Code Review Process

1. All PRs require at least one approval
2. CI/CD checks must pass
3. Code must follow style guidelines
4. Tests must pass
5. No merge conflicts

## Community Guidelines

- Be respectful and inclusive
- Provide constructive feedback
- Help others learn and grow
- Focus on what is best for the project

## Questions?

- Create a [GitHub Discussion](https://github.com/yourusername/pumpfunds/discussions)
- Join our Discord (if available)
- Email: dev@pumpfunds.io

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
