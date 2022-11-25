import 'package:micropass_api/micropass_api.dart';
import 'package:faker/faker.dart';
import 'package:test/test.dart';

void main() {
  var email = '_demo_${faker.internet.email()}';
  var masterPassword = faker.internet.password();

  var accessToken = '';
  var refreshToken = '';

  group('Identity', () {
    final client = IdentityApi();

    test('Register', () async {
      await client.register(email, masterPassword, null);
    });

    test('Login', () async {
      final response = await client.login(email, masterPassword);

      if (response.accessToken == null) {
        throw Exception("accessToken returned by API is null");
      }

      if (response.refreshToken == null) {
        throw Exception("refreshToken returned by API is null");
      }

      accessToken = response.accessToken!;
      refreshToken = response.refreshToken!;
    });

    test('Refresh Token', () async {
      final response = await client.refreshToken(refreshToken);

      if (response.accessToken == null) {
        throw Exception("accessToken returned by API is null");
      }
    });
  });

  var encryptionKey = '';

  group('User', () {
    var client = UserApi(accessToken);

    setUp(() {
      client = UserApi(accessToken);
    });

    test('Encryption Key', () async {
      encryptionKey = await client.encryptionKey(masterPassword, email);
    });

    test('Whoami', () async {
      final response = await client.whoami();

      if (response.email != email) {
        throw Exception("Response email and user email aren't the same.");
      }
    });
  });

  group('Ciphers', () {
    var client = CiphersApi(accessToken, encryptionKey);

    setUp(() {
      client = CiphersApi(accessToken, encryptionKey);
    });

    Future<void> insert() async {
      final cipher = Cipher(
        data: CipherData(
            type: CipherType.login,
            name: 'Example',
            typedFields: TypedFields(
              username: faker.internet.email(),
              password: faker.internet.password(),
            )),
      );

      await client.insert(cipher);
    }

    test('Insert (1)', () async {
      await insert();
    });

    test('Insert (2)', () async {
      await insert();
    });

    var ciphers = [];

    test('List', () async {
      final response = await client.list(null);

      ciphers = response.updated!;
    });

    var deletedUnix = 0;

    test('Delete (1)', () async {
      final id = ciphers[0];
      ciphers.remove(id);

      deletedUnix = (DateTime.now().millisecondsSinceEpoch / 1000).floor();

      await client.delete(id);
    });

    test('List (Last Sync)', () async {
      await client.list(deletedUnix);
    });

    test('Take', () async {
      for (var id in ciphers) {
        await client.take(id);
      }
    });

    test('Update', () async {
      final cipher = Cipher(
        data: CipherData(
            type: CipherType.login,
            name: 'Example',
            fields: {
              'Custom': 'Text in the custom field',
            },
            typedFields: TypedFields(
              username: faker.internet.email(),
              password: faker.internet.password(),
            )),
      );

      await client.update(ciphers[0], cipher);
    });

    test('Delete', () async {
      for (var id in ciphers) {
        await client.delete(id);
      }
    });
  });
}
