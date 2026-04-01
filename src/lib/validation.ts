import { z } from "zod";

/**
 * Validation schemas for SitEasy API routes
 * Using Zod for type-safe runtime validation
 */

// Payment schemas
export const paymentInitializeSchema = z.object({
  bookingId: z.string().uuid("Invalid booking ID"),
});

export const paymentVerifySchema = z.object({
  reference: z.string().min(1, "Reference is required"),
});

// Booking schemas
export const createBookingSchema = z.object({
  sitterId: z.string().uuid("Invalid sitter ID"),
  serviceType: z.enum(["pet_sitting", "house_sitting"]),
  startDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Invalid date format (YYYY-MM-DD)"),
  endDate: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Invalid date format (YYYY-MM-DD)"),
  notes: z.string().max(1000).optional(),
  meetGreetSlots: z.array(
    z.object({
      date: z.string().regex(/^\d{4}-\d{2}-\d{2}$/, "Invalid slot date format (YYYY-MM-DD)"),
      start_time: z.string().regex(/^\d{2}:\d{2}$/, "Invalid slot start time format (HH:MM)"),
      end_time: z.string().regex(/^\d{2}:\d{2}$/, "Invalid slot end time format (HH:MM)"),
    })
  ).optional(),
});

export const updateBookingStatusSchema = z.object({
  status: z.enum(["pending", "confirmed", "in_progress", "completed", "cancelled"]),
  reason: z.string().max(500).optional(),
});

// Message schemas
export const sendMessageSchema = z.object({
  conversationId: z.string().uuid("Invalid conversation ID").optional(),
  bookingId: z.string().uuid("Invalid booking ID").optional(),
  content: z.string().min(1, "Message cannot be empty").max(5000, "Message too long"),
});

// Review schemas
export const createReviewSchema = z.object({
  bookingId: z.string().uuid("Invalid booking ID"),
  revieweeId: z.string().uuid("Invalid reviewee ID"),
  rating: z.number().int().min(1).max(5),
  comment: z.string().max(1000).optional(),
});

// Profile update schemas
export const updateProfileSchema = z.object({
  firstName: z.string().min(1).max(50).optional(),
  lastName: z.string().min(1).max(50).optional(),
  phone: z.string().max(20).optional(),
  city: z.string().max(100).optional(),
  suburb: z.string().max(100).optional(),
});

export const updateSitterProfileSchema = z.object({
  bio: z.string().max(2000).optional(),
  services: z.array(z.enum(["pet_sitting", "house_sitting"])).optional(),
  petTypes: z.array(z.enum(["dogs", "cats", "birds", "fish", "reptiles", "small_mammals", "other"])).optional(),
  yearsExperience: z.number().int().min(0).max(50).optional(),
  hasOwnTransport: z.boolean().optional(),
});

// Helper function to validate and parse request body
export async function validateRequestBody<T>(
  request: Request,
  schema: z.ZodSchema<T>
): Promise<{ success: true; data: T } | { success: false; error: string }> {
  try {
    const body = await request.json();
    const result = schema.safeParse(body);
    
    if (!result.success) {
      const errors = result.error.issues.map((e) => e.message).join(", ");
      return { success: false, error: errors };
    }
    
    return { success: true, data: result.data };
  } catch {
    return { success: false, error: "Invalid JSON body" };
  }
}

// Type exports for use in components
export type CreateBookingInput = z.infer<typeof createBookingSchema>;
export type UpdateProfileInput = z.infer<typeof updateProfileSchema>;
export type SendMessageInput = z.infer<typeof sendMessageSchema>;
export type CreateReviewInput = z.infer<typeof createReviewSchema>;
