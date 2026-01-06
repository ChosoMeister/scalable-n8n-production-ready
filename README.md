# 🚀 Scaling n8n with Docker Compose

این پروژه یک **setup مقیاس‌پذیر برای n8n** است که از معماری **Queue Mode** استفاده می‌کند.

---

## معماری سیستم

```
                    ┌─────────────────────────────────────────────────────────────┐
                    │                         External                            │
                    │   Users ──────┐                                             │
                    │               ├──► Reverse Proxy (Nginx/Traefik)           │
                    │   Webhooks ───┘            │                                │
                    └────────────────────────────┼────────────────────────────────┘
                                                 │
                    ┌────────────────────────────┼────────────────────────────────┐
                    │                   n8n Stack│                                │
                    │                            ▼                                │
                    │              ┌─────────────────────────┐                    │
                    │              │      n8n Main           │                    │
                    │              │   (Editor + API)        │                    │
                    │              │      :5678              │                    │
                    │              └───────────┬─────────────┘                    │
                    │                          │                                  │
                    │         ┌────────────────┼────────────────┐                 │
                    │         ▼                ▼                ▼                 │
                    │   ┌──────────┐    ┌──────────┐    ┌──────────────┐          │
                    │   │ Worker 1 │    │ Worker N │    │Webhook Worker│          │
                    │   │          │    │          │    │    :5679     │          │
                    │   └────┬─────┘    └────┬─────┘    └──────┬───────┘          │
                    │        │               │                 │                  │
                    │        └───────────────┼─────────────────┘                  │
                    │                        ▼                                    │
                    │              ┌─────────────────────┐                        │
                    │              │       Redis         │                        │
                    │              │   (Message Queue)   │                        │
                    │              └─────────────────────┘                        │
                    │                        │                                    │
                    │                        ▼                                    │
                    │              ┌─────────────────────┐                        │
                    │              │     PgBouncer       │                        │
                    │              │ (Connection Pooler) │                        │
                    │              └──────────┬──────────┘                        │
                    │                         ▼                                   │
                    │              ┌─────────────────────┐                        │
                    │              │    PostgreSQL 17    │                        │
                    │              │     (Database)      │                        │
                    │              └─────────────────────┘                        │
                    └─────────────────────────────────────────────────────────────┘
```

---

## 📂 ساختار پروژه

```
scalable-n8n-production-ready/
├── compose.yaml             # Docker Compose اصلی
├── setup.sh                 # ✨ اسکریپت نصب خودکار
├── .env.example             # نمونه تنظیمات (همه در یک فایل)
├── .gitignore               # فایل‌های ignore شده در git
├── pgbouncer.ini.example    # نمونه تنظیمات PgBouncer
├── userlist.txt.example     # نمونه یوزرهای PgBouncer
├── init-data.sh             # اسکریپت ایجاد یوزر DB
└── README.md                # این فایل
```

---

## ⚙️ سرویس‌ها

| سرویس | Image | وظیفه | پورت |
|-------|-------|-------|------|
| **PostgreSQL 17** | `postgres:17` | دیتابیس اصلی | 5432 (internal) |
| **PgBouncer** | `edoburu/pgbouncer:v1.24.1-p0` | Connection Pooling | 6432 (internal) |
| **Redis** | `redis:7-alpine` | Message Queue | 6379 (internal) |
| **n8n Main** | `n8nio/n8n:stable` | Editor/API | 5678 |
| **Worker** | `n8nio/n8n:stable` | اجرای workflows | - |
| **Webhook Worker** | `n8nio/n8n:stable` | دریافت webhooks | 5679 |

---

## 🔒 تنظیمات امنیتی

### Environment Variables در `.env-main`:

| Variable | توضیح |
|----------|-------|
| `NODE_ENV=production` | حالت production برای Node.js |
| `N8N_SECURE_COOKIE=true` | ارسال cookies فقط روی HTTPS |
| `N8N_ENCRYPTION_KEY` | رمزنگاری credentials (باید منحصر به فرد باشد) |
| `N8N_BLOCK_ENV_ACCESS_IN_NODE=true` | جلوگیری از دسترسی به env در Code nodes |
| `N8N_ENFORCE_SETTINGS_FILE_PERMISSIONS=true` | بررسی دسترسی فایل‌ها |
| `QUEUE_BULL_REDIS_PASSWORD` | پسورد Redis |

### تولید مقادیر امن:

```bash
# Encryption Key
openssl rand -hex 32

# Redis Password
openssl rand -base64 24

# Database Password
openssl rand -base64 24
```

---

## 🌐 تنظیمات دامنه

این setup نیاز به **دو دامنه جداگانه** دارد:

| دامنه | سرویس | پورت داخلی |
|-------|-------|------------|
| `https://n8n.yourdomain.com` | n8n Main (UI/API) | 5678 |
| `https://n8n-webhook.yourdomain.com` | Webhook Worker | 5679 |

در `.env-main`:
```env
N8N_HOST=n8n.yourdomain.com
N8N_PROTOCOL=https
N8N_EDITOR_BASE_URL=https://n8n.yourdomain.com
WEBHOOK_URL=https://n8n-webhook.yourdomain.com
```

---

## 📊 Resource Limits

| سرویس | Memory Limit | Memory Reserved |
|-------|-------------|-----------------|
| n8n Main | 2GB | 1GB |
| Worker | 1GB | 512MB |
| Webhook Worker | 1GB | 512MB |

---

## 🔧 تنظیمات PgBouncer

فایل `pgbouncer.ini`:

| Setting | مقدار | توضیح |
|---------|-------|-------|
| `pool_mode` | transaction | هر query اتصال جدید می‌گیرد |
| `max_client_conn` | 1000 | حداکثر اتصال از clients |
| `default_pool_size` | 50 | اتصالات همزمان به PostgreSQL |
| `min_pool_size` | 5 | حداقل اتصالات باز |
| `reserve_pool_size` | 20 | اتصالات اضطراری |

فایل `userlist.txt`:
```txt
"n8n_user" "YOUR_DB_PASSWORD"
```

> ⚠️ برای امنیت بیشتر از md5 hash استفاده کنید: `"n8n_user" "md5<hash>"`
>
> تولید md5: `echo -n "YOUR_PASSWORD+n8n_user" | md5sum`

---

## ▶️ راه‌اندازی

### راه سریع (پیشنهادی)

```bash
git clone https://github.com/ChosoMeister/scalable-n8n-production-ready.git
cd scalable-n8n-production-ready
./setup.sh
docker compose up -d
```

> اسکریپت setup به صورت خودکار پسوردهای امن تولید می‌کنه و همه فایل‌ها رو آماده می‌کنه.

### راه دستی

```bash
# 1. Clone
git clone https://github.com/ChosoMeister/scalable-n8n-production-ready.git
cd scalable-n8n-production-ready

# 2. کپی فایل‌های نمونه
cp .env.example .env
cp pgbouncer.ini.example pgbouncer.ini
cp userlist.txt.example userlist.txt

# 3. تولید پسوردهای امن و جایگزینی در فایل‌ها
nano .env           # تمام تنظیمات اینجاست
nano pgbouncer.ini  # DB Password
nano userlist.txt   # DB Password

# 4. شروع
docker compose up -d
```

### دسترسی

- **n8n Editor:** http://localhost:5678
- **Webhook Worker:** http://localhost:5679

---

## 📌 Scale کردن Workers

```bash
# 3 worker
docker compose up -d --scale worker=3

# 5 worker
docker compose up -d --scale worker=5
```

**محاسبه ظرفیت:**
```
Workers × Concurrency = Total Parallel Executions
5 workers × 10 concurrency = 50 workflow همزمان
```

---

## 🔄 Workflow اجرا

```
1. Trigger/Webhook ─────► n8n Main
                              │
2.                     Create Job
                              │
3.                    ─────► Redis Queue
                              │
4.                     Worker picks job
                              │
5. Worker ◄───────────────────┘
      │
6.    └───► Get workflow from PostgreSQL
      │
7.    └───► Execute workflow
      │
8.    └───► Save results to PostgreSQL
      │
9.    └───► Notify Redis (complete)
```

---

## 📋 تنظیمات Execution

در `.env-main`:

| Variable | مقدار | توضیح |
|----------|-------|-------|
| `EXECUTIONS_TIMEOUT` | 3600 | حداکثر زمان اجرا (ثانیه) |
| `EXECUTIONS_DATA_PRUNE` | true | حذف خودکار execution های قدیمی |
| `EXECUTIONS_DATA_MAX_AGE` | 168 | نگهداری تا 168 ساعت (7 روز) |
| `EXECUTIONS_DATA_SAVE_ON_ERROR` | all | ذخیره همه خطاها |
| `EXECUTIONS_DATA_SAVE_ON_SUCCESS` | all | ذخیره همه موفقیت‌ها |

---

## 🕐 Timezone

```env
GENERIC_TIMEZONE=Asia/Tehran
TZ=Asia/Tehran
```

> مهم برای اجرای صحیح Cron triggers و Schedule nodes

---

## 🔍 دستورات مفید

```bash
# مشاهده وضعیت
docker compose ps

# لاگ‌ها
docker compose logs -f n8n
docker compose logs -f worker
docker compose logs -f webhook-worker

# Stop
docker compose down

# Stop + حذف volumes
docker compose down -v

# Restart یک سرویس
docker compose restart n8n

# بررسی config
docker compose config
```

---

## ⚠️ نکات مهم

### 1. Reverse Proxy

این setup **شامل reverse proxy نیست**. باید جداگانه تنظیم کنید:
- Nginx
- Traefik
- Caddy
- HAProxy

### 2. SSL/HTTPS

حتماً از HTTPS استفاده کنید:
- `N8N_SECURE_COOKIE=true` نیاز به HTTPS دارد
- Webhooks امن نیستند بدون HTTPS

### 3. Backup

Volume ها را backup کنید:
- `db_storage` - دیتابیس
- `n8n_storage` - فایل‌های n8n

```bash
# Backup database
docker compose exec postgres pg_dump -U lucas n8n > backup.sql
```

### 4. N8N_TRUSTED_PROXIES

اگر پشت reverse proxy هستید:
```env
N8N_TRUSTED_PROXIES=10.0.0.0/8,172.16.0.0/12,192.168.0.0/16
```

> ⚠️ **هرگز** از `*` استفاده نکنید!

---

## 📚 منابع

- [n8n Documentation](https://docs.n8n.io/)
- [n8n Queue Mode](https://docs.n8n.io/hosting/scaling/queue-mode/)
- [n8n Environment Variables](https://docs.n8n.io/hosting/configuration/environment-variables/)
- [PgBouncer Documentation](https://www.pgbouncer.org/config.html)

---

## ✅ Checklist قبل از Production

- [ ] `N8N_ENCRYPTION_KEY` منحصر به فرد تنظیم شده
- [ ] `REDIS_PASSWORD` قوی تنظیم شده
- [ ] پسوردهای دیتابیس قوی هستند
- [ ] دامنه‌های واقعی تنظیم شده
- [ ] HTTPS فعال است
- [ ] Reverse proxy تنظیم شده
- [ ] Backup strategy دارید
- [ ] Monitoring تنظیم شده
