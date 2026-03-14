import 'dart:convert';
import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cryptography/cryptography.dart';

class CryptoService {
	static const _privateKeyKey = 'x25519_private_seed';

	/// Ensure a deterministic X25519 keypair exists locally and publish public key.
	/// Returns base64 public key string.
	static Future<String> ensureKeypairAndPublish(String uid) async {
		final prefs = await SharedPreferences.getInstance();
		final existing = prefs.getString(_privateKeyKey);
		final algorithm = X25519();

		if (existing == null) {
			final keyPair = await algorithm.newKeyPair();
			final privateBytes = await keyPair.extractPrivateKeyBytes();
			final publicKey = await keyPair.extractPublicKey();
			final pubBytes = publicKey.bytes;
			final privB64 = base64Encode(privateBytes);
			final pubB64 = base64Encode(pubBytes);
			await prefs.setString(_privateKeyKey, privB64);
			await FirebaseFirestore.instance.collection('users').doc(uid).set({'publicKey': pubB64}, SetOptions(merge: true));
			return pubB64;
		} else {
			final seed = base64Decode(existing);
			final keyPair = await algorithm.newKeyPairFromSeed(seed);
			final publicKey = await keyPair.extractPublicKey();
			final pubBytes = publicKey.bytes;
			final pubB64 = base64Encode(pubBytes);
			await FirebaseFirestore.instance.collection('users').doc(uid).set({'publicKey': pubB64}, SetOptions(merge: true));
			return pubB64;
		}
	}

	static Future<Uint8List?> _getSeed() async {
		final prefs = await SharedPreferences.getInstance();
		final s = prefs.getString(_privateKeyKey);
		if (s == null) return null;
		return Uint8List.fromList(base64Decode(s));
	}

	/// Encrypt [content] for a receiver identified by [receiverPubBase64].
	/// Returns a base64-encoded JSON payload containing nonce, cipher, mac and senderPub.
	static Future<String> encryptFor(String receiverPubBase64, String content) async {
		final algorithm = X25519();
		final seed = await _getSeed();
		if (seed == null) throw Exception('Private key not found; call ensureKeypairAndPublish(uid) first');

		final myKeyPair = await algorithm.newKeyPairFromSeed(seed);
		final receiverPubBytes = base64Decode(receiverPubBase64);
		final receiverPub = SimplePublicKey(receiverPubBytes, type: KeyPairType.x25519);

		final sharedSecret = await algorithm.sharedSecretKey(keyPair: myKeyPair, remotePublicKey: receiverPub);

		// derive symmetric key via HKDF-SHA256
		final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
		final derived = await hkdf.deriveKey(secretKey: sharedSecret, info: utf8.encode('modelx chat key'));
		final secretKeyBytes = await derived.extractBytes();
		final secretKey = SecretKey(secretKeyBytes);

		// encrypt using ChaCha20-Poly1305 (AEAD)
		final cipher = Chacha20.poly1305Aead();
		final plaintext = utf8.encode(content);
		final secretBox = await cipher.encrypt(plaintext, secretKey: secretKey);

		final myPub = (await myKeyPair.extractPublicKey()).bytes;
		final payload = {
			'nonce': base64Encode(secretBox.nonce),
			'cipher': base64Encode(secretBox.cipherText),
			'mac': base64Encode(secretBox.mac.bytes),
			'senderPub': base64Encode(myPub),
		};

		return base64Encode(utf8.encode(jsonEncode(payload)));
	}

	/// Decrypt a base64 JSON payload produced by [encryptFor].
	static Future<String> decrypt(String payloadBase64) async {
		final algorithm = X25519();
		final seed = await _getSeed();
		if (seed == null) throw Exception('Private key not found');

		final myKeyPair = await algorithm.newKeyPairFromSeed(seed);

		final payloadJson = utf8.decode(base64Decode(payloadBase64));
		final payload = jsonDecode(payloadJson) as Map<String, dynamic>;
		final nonce = base64Decode(payload['nonce']);
		final cipherText = base64Decode(payload['cipher']);
		final macBytes = base64Decode(payload['mac']);
		final senderPubBytes = base64Decode(payload['senderPub']);
		final senderPub = SimplePublicKey(senderPubBytes, type: KeyPairType.x25519);

		final sharedSecret = await algorithm.sharedSecretKey(keyPair: myKeyPair, remotePublicKey: senderPub);
		final hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);
		final derived = await hkdf.deriveKey(secretKey: sharedSecret, info: utf8.encode('modelx chat key'));
		final secretKeyBytes = await derived.extractBytes();
		final secretKey = SecretKey(secretKeyBytes);

		final cipher = Chacha20.poly1305Aead();
		final secretBox = SecretBox(Uint8List.fromList(cipherText), nonce: Uint8List.fromList(nonce), mac: Mac(macBytes));
		final plain = await cipher.decrypt(secretBox, secretKey: secretKey);
		return utf8.decode(plain);
	}
}


