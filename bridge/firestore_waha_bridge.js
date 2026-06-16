// bridge/firestore_waha_bridge.js
const admin = require('firebase-admin');
const http = require('http');
const serviceAccount = require('./serviceAccountKey.json');

let nodemailer;
try {
  nodemailer = require('nodemailer');
} catch (e) {
  console.log('⚠️ Warning: nodemailer tidak terinstal. Silakan jalankan: npm install nodemailer');
}

// Konfigurasi Email (Silakan ganti dengan detail Gmail Anda)
const EMAIL_CONFIG = {
  service: 'gmail',
  auth: {
    user: 'duluinapp@gmail.com',         // Gantilah dengan Gmail Anda
    pass: 'oxyqlgtlcyncnisn'    // Gantilah dengan Sandi Aplikasi 16-karakter
  }
};

async function sendEmail(to, subject, text) {
  if (!nodemailer) {
    console.warn('⚠️ Nodemailer belum diinstal. Email tidak dapat dikirim.');
    return { success: false, skipped: true };
  }
  if (EMAIL_CONFIG.auth.user === 'GMAIL_ANDA@gmail.com' || EMAIL_CONFIG.auth.pass === 'KODE_SANDI_APLIKASI_GMAIL') {
    console.log(`⚠️ Konfigurasi email default terdeteksi. Silakan edit file bridge untuk mengatur sandi aplikasi Gmail Anda. Lewati kirim ke ${to}`);
    return { success: false, skipped: true };
  }

  try {
    const transporter = nodemailer.createTransport({
      service: EMAIL_CONFIG.service,
      auth: EMAIL_CONFIG.auth
    });

    await transporter.sendMail({
      from: EMAIL_CONFIG.auth.user,
      to: to,
      subject: subject,
      text: text
    });
    console.log(`✉️ Email pengingat berhasil dikirim ke ${to}`);
    return { success: true, skipped: false };
  } catch (error) {
    console.error(`❌ Gagal mengirim email ke ${to}:`, error);
    return { success: false, skipped: false };
  }
}

// Inisialisasi Firebase Admin SDK
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const WAHA_URL = 'http://localhost:3000/api/sendText';
const WAHA_API_KEY = '9900041c319447d08033527385828bb1'; // Kunci API WAHA Anda dari Swagger/Docker

console.log('🤖 ======================================================');
console.log('🤖 Duluin Firestore-to-WAHA Bridge Aktif...');
console.log('🤖 Menunggu tugas-tugas dari Firebase Cloud...');
console.log('🤖 ======================================================');

async function checkReminders() {
  try {
    const now = new Date();
    console.log(`[${now.toLocaleString()}] Memeriksa tugas di Firestore...`);

    // Ambil semua tugas yang statusnya belum selesai ('aktif' atau 'terlambat')
    const snapshot = await db.collection('tasks')
      .where('state', '!=', 'selesai')
      .get();

    for (const doc of snapshot.docs) {
      const task = doc.data();
      const taskId = doc.id;
      const name = task.name || '';
      const deadlineStr = task.deadline; // format: 'YYYY-MM-DD HH:mm:ss'
      const whatsappNumber = task.whatsapp_number || '';
      const email = task.email || '';
      const remind1d = task.remind_1d || false;
      const remind1h = task.remind_1h || false;
      const isWaSent1d = task.is_wa_sent_1d || false;
      const isWaSent1h = task.is_wa_sent_1h || false;
      const isEmailSent1d = task.is_email_sent_1d || false;
      const isEmailSent1h = task.is_email_sent_1h || false;

      // Lewati jika tidak ada nomor tujuan (WA & Email kosong) ATAU tidak menyalakan pengingat
      if ((!whatsappNumber && !email) || (!remind1d && !remind1h)) continue;

      // Parsing format tanggal 'yyyy-MM-dd HH:mm:ss'
      let deadline;
      try {
        const parts = deadlineStr.split(' ');
        const dateParts = parts[0].split('-');
        const timeParts = parts[1].split(':');
        deadline = new Date(
          parseInt(dateParts[0]),
          parseInt(dateParts[1]) - 1,
          parseInt(dateParts[2]),
          parseInt(timeParts[0]),
          parseInt(timeParts[1]),
          parseInt(timeParts[2] || '0')
        );
      } catch (e) {
        deadline = new Date(deadlineStr);
      }

      if (isNaN(deadline.getTime())) {
        console.error(`⚠️ Format tanggal salah untuk tugas "${name}": ${deadlineStr}`);
        continue;
      }

      // Alinhkan waktu ke tingkat menit untuk keakuratan tinggi
      const nowAligned = new Date(now.getFullYear(), now.getMonth(), now.getDate(), now.getHours(), now.getMinutes(), 0, 0);
      const deadlineAligned = new Date(deadline.getFullYear(), deadline.getMonth(), deadline.getDate(), deadline.getHours(), deadline.getMinutes(), 0, 0);

      const diffMs = deadlineAligned - nowAligned;
      const diffMinutes = Math.round(diffMs / (1000 * 60));

      // 1. Pengingat H-1 Hari (Kirim jika sisa waktu <= 1440 menit (24 jam) dan > 60 menit (1 jam), serta belum terkirim)
      if (diffMinutes > 60 && diffMinutes <= 1440) {
        // WhatsApp H-1 Hari
        if (remind1d && whatsappNumber && !isWaSent1d) {
          console.log(`⏰ Menyiapkan pengingat WA H-1 Hari untuk tugas "${name}" ke ${whatsappNumber}...`);
          const message = `🔔 *PENGINGAT H-1 HARI (Duluin)*\n\nHalo! Tugas/Agenda Anda:\n📌 *${name}*\n📅 Deadline: ${deadlineStr}\n\nJangan lupa dibereskan ya! 💪`;
          const success = await sendWhatsApp(whatsappNumber, message);
          if (success) {
            await db.collection('tasks').doc(taskId).update({ is_wa_sent_1d: true });
            console.log(`✅ Status pengingat WA H-1 Hari untuk "${name}" diperbarui di Firestore.`);
          }
        }

        // Email H-1 Hari
        if (remind1d && email && !isEmailSent1d) {
          console.log(`⏰ Menyiapkan pengingat Email H-1 Hari untuk tugas "${name}" ke ${email}...`);
          const subject = `🔔 Pengingat H-1 Hari: ${name}`;
          const text = `Halo!\n\nTugas/Agenda Anda:\n📌 Nama: ${name}\n📅 Deadline: ${deadlineStr}\n\nJangan lupa dibereskan ya! 💪\n\nSalam,\nTim Duluin App`;
          const result = await sendEmail(email, subject, text);
          if (result.success || result.skipped) {
            await db.collection('tasks').doc(taskId).update({ is_email_sent_1d: true });
            if (result.success) {
              console.log(`✅ Status pengingat Email H-1 Hari untuk "${name}" diperbarui di Firestore.`);
            }
          }
        }
      }

      // 2. Pengingat H-1 Jam (Kirim jika sisa waktu <= 60 menit (1 jam) dan belum terkirim)
      if (diffMinutes > 0 && diffMinutes <= 60) {
        // WhatsApp H-1 Jam
        if (remind1h && whatsappNumber && !isWaSent1h) {
          console.log(`⏰ Menyiapkan pengingat WA H-1 Jam untuk tugas "${name}" ke ${whatsappNumber}...`);
          const message = `🚨 *PENGINGAT H-1 JAM (Duluin)*\n\nHalo! Waktu tugas Anda sisa 1 jam lagi:\n📌 *${name}*\n📅 Deadline: ${deadlineStr}\n\nAyo segera selesaikan! ⚡`;
          const success = await sendWhatsApp(whatsappNumber, message);
          if (success) {
            await db.collection('tasks').doc(taskId).update({ is_wa_sent_1h: true });
            console.log(`✅ Status pengingat WA H-1 Jam untuk "${name}" diperbarui di Firestore.`);
          }
        }

        // Email H-1 Jam
        if (remind1h && email && !isEmailSent1h) {
          console.log(`⏰ Menyiapkan pengingat Email H-1 Jam untuk tugas "${name}" ke ${email}...`);
          const subject = `🚨 Pengingat H-1 Jam: ${name}`;
          const text = `Halo!\n\nTugas/Agenda Anda:\n📌 Nama: ${name}\n📅 Deadline: ${deadlineStr}\n\nWaktu tersisa tinggal 1 jam lagi! Ayo segera selesaikan! ⚡\n\nSalam,\nTim Duluin App`;
          const result = await sendEmail(email, subject, text);
          if (result.success || result.skipped) {
            await db.collection('tasks').doc(taskId).update({ is_email_sent_1h: true });
            if (result.success) {
              console.log(`✅ Status pengingat Email H-1 Jam untuk "${name}" diperbarui di Firestore.`);
            }
          }
        }
      }
    }
  } catch (error) {
    console.error('❌ Error saat memeriksa pengingat:', error);
  }
}

function sendWhatsApp(to, text) {
  return new Promise((resolve) => {
    // Normalisasi nomor WA (hilangkan karakter non-angka, ubah 0 di depan ke 62)
    let cleanTo = to.replace(/[^0-9]/g, '');
    if (cleanTo.startsWith('0')) {
      cleanTo = '62' + cleanTo.substring(1);
    }

    const payload = JSON.stringify({
      chatId: `${cleanTo}@c.us`,
      text: text,
      session: 'default'
    });

    const headers = {
      'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(payload)
    };
    if (WAHA_API_KEY && WAHA_API_KEY.trim() !== '') {
      headers['X-Api-Key'] = WAHA_API_KEY.trim();
    }

    const url = new URL(WAHA_URL);
    const options = {
      hostname: url.hostname,
      port: url.port || 80,
      path: url.pathname,
      method: 'POST',
      headers: headers
    };

    const req = http.request(options, (res) => {
      let data = '';
      res.on('data', (chunk) => { data += chunk; });
      res.on('end', () => {
        if (res.statusCode >= 200 && res.statusCode < 300) {
          console.log(`✉️ Pesan WA berhasil dikirim ke ${cleanTo}`);
          resolve(true);
        } else {
          console.error(`❌ WAHA mengembalikan status error ${res.statusCode}:`, data);
          resolve(false);
        }
      });
    });

    req.on('error', (error) => {
      console.error(`❌ Gagal terhubung ke WAHA PC (${WAHA_URL}):`, error.message);
      resolve(false);
    });

    req.write(payload);
    req.end();
  });
}

// Jalankan pencarian saat dijalankan, lalu sejajarkan interval berikutnya tepat di awal menit
checkReminders();

const msToNextMinute = (60 - new Date().getSeconds()) * 1000 - new Date().getMilliseconds();
setTimeout(() => {
  checkReminders();
  setInterval(checkReminders, 60 * 1000);
}, msToNextMinute);
