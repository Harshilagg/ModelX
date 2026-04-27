// lib/services/email_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'ai_config.dart';

class EmailService {
  final String _apiKey = AiConfig.sendGridApiKey;
  final String _fromEmail = 'aggarwalharshil02@gmail.com'; 
  final String _fromName = 'ModelX Team';

  Future<void> sendInvitationEmail({
    required String recipientEmail,
    required String agencyName,
    required String role,
    required String inviteLink,
  }) async {
    final url = Uri.parse('https://api.sendgrid.com/v3/mail/send');
    
    final payload = {
      'personalizations': [
        {
          'to': [{'email': recipientEmail}],
          'subject': 'You have been invited to join $agencyName on ModelX'
        }
      ],
      'from': {
        'email': _fromEmail,
        'name': _fromName
      },
      'content': [
        {
          'type': 'text/html',
          'value': '''
            <div style="font-family: sans-serif; max-width: 600px; margin: 0 auto; padding: 20px; border: 1px solid #eee; border-radius: 10px;">
              <h2 style="color: #0F172A;">ModelX Team Invitation</h2>
              <p>Hi there,</p>
              <p><strong>$agencyName</strong> has invited you to join their team as a <strong>$role</strong> on ModelX.</p>
              <p style="margin: 30px 0;">
                <a href="$inviteLink" style="background-color: #0F172A; color: white; padding: 12px 24px; border-radius: 6px; text-decoration: none; font-weight: bold;">Accept Invitation</a>
              </p>
              <p style="font-size: 12px; color: #666;">If the button above doesn't work, copy and paste this link into your browser:</p>
              <p style="font-size: 12px; color: #666;">$inviteLink</p>
              <hr style="border: 0; border-top: 1px solid #eee; margin: 20px 0;">
              <p style="font-size: 12px; color: #666;">This invitation will expire in 7 days.</p>
            </div>
          '''
        }
      ]
    };

    try {
      final response = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $_apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(payload),
      );

      if (response.statusCode >= 200 && response.statusCode < 300) {
        debugPrint('✅ Invitation email sent successfully to $recipientEmail');
      } else {
        debugPrint('❌ Failed to send email: ${response.statusCode} - ${response.body}');
        throw Exception('Failed to send invitation email');
      }
    } catch (e) {
      debugPrint('❌ Email Error: $e');
      throw Exception('Email service error: $e');
    }
  }
}
