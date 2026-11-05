import { useState } from 'react';
import { Archive, FileText, LayoutDashboard, LogIn, ShieldCheck } from 'lucide-react';

const types = [
  'سندات صرف عام',
  'سندات صرف حوالة',
  'سندات صرف عملاء',
  'ملفات فتح الحسابات',
  'تقارير الجرد',
  'تعديل / تغيير رقم الجوال',
  'إشعارات البنوك',
];

export default function App() {
  const [entryMode, setEntryMode] = useState<'number_range' | 'date_range'>('number_range');
  const [docType, setDocType] = useState(types[0]);

  return (
    <main className="shell">
      <header className="topbar">
        <div className="brand"><span className="brandIcon"><Archive /></span><div><strong>منصة إدارة الأرشفة</strong><small>تسليم ومتابعة المستندات</small></div></div>
        <span className="badge">نسخة تأسيسية</span>
      </header>

      <section className="welcome">
        <div className="welcomeIcon"><ShieldCheck size={30}/></div>
        <div><h1>بوابة تقارير الأرشفة</h1><p>إدارة إلكترونية لتقارير الفروع وكشوف الاستلام والتسليم</p></div>
      </section>

      <section className="cards">
        <article className="card stat"><span>إجمالي التقارير</span><b>—</b><small>تظهر بعد ربط قاعدة البيانات</small></article>
        <article className="card stat"><span>قيد المراجعة</span><b>—</b><small>حسب صلاحيات المستخدم</small></article>
        <article className="card stat"><span>معتمدة نهائياً</span><b>—</b><small>اعتماد مدير النظام أو الأرشيف</small></article>
      </section>

      <section className="card formCard">
        <div className="sectionTitle"><FileText/><div><h2>إنشاء تقرير أرشفة</h2><p>معاينة أولية للحقول الأساسية — الحفظ والإرسال يتطلبان ربط Supabase.</p></div></div>
        <div className="grid">
          <label>الفرع<select defaultValue=""><option value="" disabled>يُحدد من حساب المستخدم بعد تسجيل الدخول</option></select></label>
          <label>نوع السند أو الملف<select value={docType} onChange={e => setDocType(e.target.value)}>{types.map(t => <option key={t}>{t}</option>)}</select></label>
        </div>
        <div className="modeSwitch">
          <span>طريقة تحديد نطاق المستندات</span>
          <div>
            <button className={entryMode === 'number_range' ? 'active' : ''} onClick={() => setEntryMode('number_range')}>من رقم إلى رقم</button>
            <button className={entryMode === 'date_range' ? 'active' : ''} onClick={() => setEntryMode('date_range')}>من تاريخ إلى تاريخ</button>
          </div>
        </div>
        {entryMode === 'number_range' ? (
          <div className="grid">
            <label>من رقم<input placeholder="مثال: 1001" inputMode="numeric" /></label>
            <label>إلى رقم<input placeholder="مثال: 1500" inputMode="numeric" /></label>
          </div>
        ) : (
          <div className="grid">
            <label>من تاريخ<input type="date" /></label>
            <label>إلى تاريخ<input type="date" /></label>
          </div>
        )}
        <div className="grid">
          <label>عدد المستندات<input type="number" min="0" placeholder="أدخل العدد" /></label>
          <label>مرفق ورقي (اختياري)<input type="file" accept=".pdf,image/*" /></label>
        </div>
        <label>ملاحظات<textarea rows={3} placeholder="أدخل أي ملاحظات متعلقة بالتسليم..." /></label>
        <div className="notice">سيُعبّأ كشف الاستلام والتسليم إلكترونياً داخل المنصة. إرفاق نسخة ورقية ممسوحة ضوئياً اختياري.</div>
        <button className="primary" disabled>حفظ وإرسال التقرير — يتطلب استكمال الربط</button>
      </section>

      <section className="card workflow">
        <div className="sectionTitle"><LayoutDashboard/><div><h2>مسار التقرير</h2><p>الإجراء المعتمد في النظام</p></div></div>
        <ol>
          <li><b>إرسال الفرع</b><span>إقرار إلكتروني تلقائي باسم الموظف الرافع وتاريخ ووقت الإرسال.</span></li>
          <li><b>مراجعة التقرير</b><span>يصل إلى مدير النظام والأرشيف المركزي.</span></li>
          <li><b>الاعتماد النهائي</b><span>اعتماد أحد الطرفين يكفي، ولا يشترط اعتماد الاثنين.</span></li>
        </ol>
      </section>
      <footer><LogIn size={15}/> منصة داخلية — يلزم إعداد الحسابات والصلاحيات قبل التشغيل الفعلي</footer>
    </main>
  );
}
