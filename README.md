# SitEasy - Pet-Sitting Marketplace (Public Code Sample)

**A production-ready marketplace platform for South Africa's pet-sitting industry**

**Live Site:** [siteasy.co.za](https://siteasy.co.za) | **Case Study:** [github.com/selezai/siteasy-case-study](https://github.com/selezai/siteasy-case-study)

This is a **sanitized, public version** of the SitEasy codebase, created to demonstrate code quality, architecture patterns, and technical skills for employment purposes. Business logic and proprietary features have been replaced with generic implementations.

---

## What This Repository Contains

This public repository includes:

- **Database schema and migrations** - Full PostgreSQL schema with RLS policies
- **Type definitions** - TypeScript interfaces and Zod validation schemas
- **API route patterns** - Structure and security patterns (without business logic)
- **Utility functions** - Reusable helpers for validation, date handling, etc.
- **Component patterns** - React component architecture examples
- **Security implementations** - Rate limiting, input validation, auth patterns
- **Testing examples** - E2E test patterns with Playwright

**What's NOT included:**
- Proprietary business logic
- Specific pricing algorithms
- Custom matching/recommendation systems
- Production environment variables
- Third-party API integration details

---

## Tech Stack

**Frontend:**
- Next.js 14 (App Router)
- React 19
- TypeScript
- Tailwind CSS 4
- Lucide Icons

**Backend:**
- Next.js API Routes
- Supabase (PostgreSQL, Auth, Storage, Realtime)
- Zod (Input validation)

**Integrations:**
- Paystack (Payment processing)
- Resend (Email)
- Upstash Redis (Rate limiting)
- Sentry (Error monitoring)

**DevOps:**
- Vercel (Deployment)
- Playwright (E2E testing)
- GitHub Actions (CI/CD)

---

## Project Structure

```
siteasy-public/
├── src/
│   ├── app/                    # Next.js App Router
│   │   ├── api/               # API routes (sanitized)
│   │   │   ├── auth/          # Authentication endpoints
│   │   │   ├── bookings/      # Booking management
│   │   │   ├── payments/      # Payment processing
│   │   │   └── profile/       # User profile management
│   │   └── (auth)/            # Auth pages
│   ├── components/            # React components
│   │   ├── booking/          # Booking-related components
│   │   ├── dashboard/        # Dashboard layouts
│   │   └── ui/               # Reusable UI components
│   ├── lib/                   # Utilities and helpers
│   │   ├── supabase/         # Supabase clients
│   │   ├── validation.ts     # Zod schemas
│   │   ├── rateLimit.ts      # Rate limiting
│   │   └── utils.ts          # Helper functions
│   └── middleware.ts          # Auth middleware
├── supabase/
│   └── migrations/            # Database migrations
├── tests/                     # Playwright E2E tests
└── docs/                      # Additional documentation
```

---

## Key Features Demonstrated

### 1. Database Architecture
- 15-table PostgreSQL schema
- Row-Level Security (RLS) policies
- Exclusion constraints for booking overlap prevention
- Stored procedures for complex operations
- Automatic timestamp triggers

### 2. Authentication & Authorization
- Supabase Auth integration
- Role-based access control (client, sitter, agency)
- Protected API routes
- Middleware-based route protection

### 3. Payment Processing
- Paystack integration patterns
- Webhook signature verification
- Transaction state management
- Refund processing
- Idempotent operations

### 4. Real-Time Features
- Supabase Realtime for messaging
- Optimistic UI updates
- Live notifications

### 5. Security Best Practices
- Input validation with Zod
- Rate limiting (Upstash Redis)
- CSRF protection
- SQL injection prevention
- XSS protection
- Comprehensive security audit completed

### 6. Code Quality
- TypeScript strict mode
- ESLint configuration
- Consistent error handling
- Comprehensive type safety
- E2E testing with Playwright

---

## Database Schema Highlights

**Core Tables:**
- `profiles` - User accounts with role-based access
- `sitter_profiles` - Sitter-specific data
- `client_profiles` - Client home details
- `bookings` - Booking lifecycle management
- `transactions` - Payment tracking
- `messages` - Real-time messaging
- `reviews` - Rating system

**Key Constraints:**
```sql
-- Prevent double-booking sitters
ALTER TABLE bookings 
ADD CONSTRAINT no_overlapping_bookings 
EXCLUDE USING gist (
  sitter_id WITH =,
  daterange(start_date, end_date, '[]') WITH &&
) WHERE (status NOT IN ('cancelled', 'completed'));
```

---

## Code Samples Included

### Input Validation Pattern
```typescript
// lib/validation.ts
export const createBookingSchema = z.object({
  sitterId: z.string().uuid('Invalid sitter ID'),
  serviceType: z.enum(['pet_sitting', 'house_sitting']),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/),
  notes: z.string().max(1000).optional(),
});
```

### API Route Pattern
```typescript
// app/api/bookings/route.ts
export async function POST(request: Request) {
  // 1. Authentication
  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }
  
  // 2. Rate limiting
  const { success } = await checkRateLimit(user.id, 'api');
  if (!success) {
    return NextResponse.json({ error: 'Too many requests' }, { status: 429 });
  }
  
  // 3. Input validation
  const validation = await validateRequestBody(request, createBookingSchema);
  if (!validation.success) {
    return NextResponse.json({ error: validation.error }, { status: 400 });
  }
  
  // 4. Authorization check
  // 5. Business logic (sanitized in public version)
  // 6. Response
}
```

### Rate Limiting Implementation
```typescript
// lib/rateLimit.ts
export async function checkRateLimit(
  identifier: string,
  key: RateLimitKey
): Promise<{ success: boolean; remaining: number; resetIn: number }> {
  const limiter = redisLimiters[key];
  const result = await limiter.limit(identifier);
  return {
    success: result.success,
    remaining: result.remaining,
    resetIn: result.reset - Date.now(),
  };
}
```

---

## Security Implementation

### Comprehensive Security Review Conducted

All critical findings resolved:
- RLS policy hardening
- Payment amount verification
- Input validation on all routes
- Rate limiting on sensitive endpoints
- Webhook signature verification
- Double-processing prevention
- Timezone handling edge cases

**Security Review Document:** Included in `/docs/SECURITY_REVIEW.md`

---

## Development Workflow

### Local Development
```bash
npm install
npm run dev
```

### Testing
```bash
# E2E tests
npm run test:e2e

# Run in UI mode
npm run test:e2e:ui
```

### Build
```bash
npm run build
```

---

## Skills Demonstrated

**Full-Stack Development:**
- Next.js 14 App Router architecture
- Server Components and Server Actions
- API route design and implementation
- Database schema design and optimization

**TypeScript:**
- Strict type safety
- Complex type definitions
- Zod schema validation
- Type-safe API contracts

**Database:**
- PostgreSQL schema design
- Complex queries and joins
- Stored procedures
- Performance optimization
- RLS policies

**Security:**
- Authentication and authorization
- Input validation and sanitization
- Rate limiting and DDoS prevention
- Payment security
- Security audit and remediation

**DevOps:**
- Vercel deployment
- Environment management
- Error monitoring (Sentry)
- CI/CD pipelines

---

## Why This Repository Exists

This sanitized version was created to:
1. Demonstrate code quality and architecture skills to potential employers
2. Protect proprietary business logic and competitive advantage
3. Show production-grade patterns and best practices
4. Provide verifiable evidence of technical capabilities

**The actual SitEasy platform remains private** as it's an active business venture.

---

## Development Timeline

- **December 2025:** Project initialization, Sprint 1 (Sitter onboarding)
- **December 2025:** Sprints 2-5 (Client features, bookings, payments, agencies)
- **January 2026:** Timezone handling improvements
- **March 2026:** Comprehensive security review and remediation

**Total Development:**
- 5 sprints over 3 months
- 150+ commits
- 15,000+ lines of code
- 27/27 tasks completed

---

## Contact

**Developer:** Selez Massozi  
**GitHub:** [@selezai](https://github.com/selezai)  
**Case Study:** [siteasy-case-study](https://github.com/selezai/siteasy-case-study)

For employment verification or technical discussions, please contact via GitHub.

---

## License

This sanitized code sample is provided for demonstration purposes only. The actual SitEasy platform and its proprietary business logic remain private and confidential.

**Note:** This is a code sample repository. It is not a functional application and cannot be deployed as-is.
