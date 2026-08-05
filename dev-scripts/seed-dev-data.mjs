// Populates a fresh dev database with everything needed to try the app end to
// end: a customer, an approved+funded driver, and three approved restaurants.
// Safe to run repeatedly — it upserts by phone. Run it after the backend has
// started (the backend creates the schema on boot).
import { createRequire } from 'module';
const require = createRequire(
  'file:///D:/Wasl-App-main/Wasl-App/Wasl_backend_database/package.json',
);
const bcrypt = require('bcrypt');
const pg = require('pg');

const c = new pg.Client({
  host: '127.0.0.1',
  port: 5432,
  user: 'postgres',
  password: 'x',
  database: 'postgres',
});
await c.connect();

const PW = 'Flash@123';
const hash = await bcrypt.hash(PW, 10);

async function upsertUser(name, phone, role) {
  const ex = await c.query('SELECT id FROM users WHERE phone=$1', [phone]);
  if (ex.rows.length) {
    await c.query(
      'UPDATE users SET name=$2,"passwordHash"=$3,role=$4,status=\'active\' WHERE phone=$1',
      [phone, name, hash, role],
    );
    return ex.rows[0].id;
  }
  const r = await c.query(
    `INSERT INTO users (name,phone,"passwordHash",role,status)
     VALUES ($1,$2,$3,$4,'active') RETURNING id`,
    [name, phone, hash, role],
  );
  return r.rows[0].id;
}

// --- customer ---
const custId = await upsertUser('محمد القصاص', '201220346717', 'customer');

// --- driver (approved + funded so it can go online right away) ---
const drvId = await upsertUser('كابتن فلاش', '201000555001', 'delivery');
const dp = await c.query(
  'SELECT user_id FROM delivery_partners WHERE user_id=$1',
  [drvId],
);
if (dp.rows.length) {
  await c.query(
    `UPDATE delivery_partners SET balance=100,is_online=false,"verificationStatus"='approved' WHERE user_id=$1`,
    [drvId],
  );
} else {
  await c.query(
    `INSERT INTO delivery_partners
       (user_id,national_id_front,national_id_back,selfie,vehicle_image,"vehicleType","verificationStatus",balance,is_online)
     VALUES ($1,'seed.jpg','seed.jpg','seed.jpg','seed.jpg','motorcycle','approved',100,false)`,
    [drvId],
  );
}

// --- three approved restaurants near كوم حمادة ---
const LAT = 30.7649;
const LNG = 30.7003;
const restaurants = [
  { phone: '01555100001', name: 'مطعم النيل', addr: 'شارع الجمهورية، كوم حمادة', dLat: 0, dLng: 0 },
  { phone: '01555100002', name: 'مشويات الأصيل', addr: 'شارع المحطة، كوم حمادة', dLat: 0.004, dLng: 0.003 },
  { phone: '01555100003', name: 'بيتزا وبرجر هاوس', addr: 'ميدان الساعة، كوم حمادة', dLat: -0.005, dLng: 0.004 },
];
for (const r of restaurants) {
  const uid = await upsertUser(r.name, r.phone, 'merchant');
  const m = await c.query('SELECT id FROM merchants WHERE owner_id=$1', [uid]);
  if (m.rows.length) {
    await c.query(
      `UPDATE merchants SET store_name=$2,store_type='مطاعم',status='approved',latitude=$3,longitude=$4,address_details=$5 WHERE owner_id=$1`,
      [uid, r.name, LAT + r.dLat, LNG + r.dLng, r.addr],
    );
  } else {
    await c.query(
      `INSERT INTO merchants (owner_id,store_name,store_type,status,latitude,longitude,address_details)
       VALUES ($1,$2,'مطاعم','approved',$3,$4,$5)`,
      [uid, r.name, LAT + r.dLat, LNG + r.dLng, r.addr],
    );
  }
}

console.log('✅ تم تجهيز البيانات التجريبية:');
console.log('   عميل:  01220346717 / ' + PW);
console.log('   سائق:  01000555001 / ' + PW + '  (معتمد + رصيد 100)');
console.log('   3 مطاعم معتمدة');
await c.end();
