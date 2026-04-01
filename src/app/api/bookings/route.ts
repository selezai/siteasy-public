import { NextResponse } from "next/server";
import { createClient } from "@/lib/supabase/server";
import { validateRequestBody, createBookingSchema } from "@/lib/validation";
import { checkRateLimit, getClientIdentifier, rateLimitResponse } from "@/lib/rateLimit";

/**
 * API Route Pattern Example: Create Booking
 * 
 * This demonstrates the standard security pattern used across all API routes:
 * 1. Authentication check
 * 2. Rate limiting
 * 3. Input validation
 * 4. Authorization check
 * 5. Business logic (sanitized in this public version)
 * 6. Response
 */

export async function POST(request: Request) {
  try {
    // Step 1: Authentication
    const supabase = createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return NextResponse.json(
        { error: "Unauthorized" },
        { status: 401 }
      );
    }

    // Step 2: Rate Limiting
    const identifier = getClientIdentifier(request, user.id);
    const { success, resetIn } = await checkRateLimit(identifier, "api");
    
    if (!success) {
      return rateLimitResponse(resetIn);
    }

    // Step 3: Input Validation
    const validation = await validateRequestBody(request, createBookingSchema);
    
    if (!validation.success) {
      return NextResponse.json(
        { error: validation.error },
        { status: 400 }
      );
    }

    const { sitterId, serviceType, startDate, endDate, notes } = validation.data;

    // Step 4: Authorization Check
    // Verify user has permission to create bookings (must be a client)
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    if (profile?.role !== "client") {
      return NextResponse.json(
        { error: "Only clients can create bookings" },
        { status: 403 }
      );
    }

    // Step 5: Business Logic (SANITIZED)
    // In the actual application, this section includes:
    // - Pricing calculation based on service type and duration
    // - Sitter availability verification
    // - Booking overlap prevention (handled by database constraint)
    // - Platform fee calculation
    // - Meet & greet scheduling
    // - Notification sending
    
    // Generic implementation for demonstration:
    const { data: booking, error: bookingError } = await supabase
      .from("bookings")
      .insert({
        client_id: user.id,
        sitter_id: sitterId,
        service_type: serviceType,
        start_date: startDate,
        end_date: endDate,
        notes,
        status: "pending",
        // Actual pricing logic removed
        total_amount: 0,
        platform_fee: 0,
        sitter_payout: 0,
      })
      .select()
      .single();

    if (bookingError) {
      console.error("Booking creation error:", bookingError);
      return NextResponse.json(
        { error: "Failed to create booking" },
        { status: 500 }
      );
    }

    // Step 6: Response
    return NextResponse.json(
      {
        success: true,
        booking,
        message: "Booking created successfully",
      },
      { status: 201 }
    );

  } catch (error) {
    console.error("Unexpected error in POST /api/bookings:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}

/**
 * GET /api/bookings
 * Retrieve bookings for the authenticated user
 */
export async function GET(request: Request) {
  try {
    const supabase = createClient();
    const { data: { user }, error: authError } = await supabase.auth.getUser();
    
    if (authError || !user) {
      return NextResponse.json({ error: "Unauthorized" }, { status: 401 });
    }

    // Rate limiting
    const identifier = getClientIdentifier(request, user.id);
    const { success, resetIn } = await checkRateLimit(identifier, "api");
    
    if (!success) {
      return rateLimitResponse(resetIn);
    }

    // Get user role to determine which bookings to fetch
    const { data: profile } = await supabase
      .from("profiles")
      .select("role")
      .eq("id", user.id)
      .single();

    let query = supabase
      .from("bookings")
      .select(`
        *,
        client:profiles!client_id(id, first_name, last_name, avatar_url),
        sitter:profiles!sitter_id(id, first_name, last_name, avatar_url)
      `)
      .order("created_at", { ascending: false });

    // Filter based on role
    if (profile?.role === "client") {
      query = query.eq("client_id", user.id);
    } else if (profile?.role === "sitter") {
      query = query.eq("sitter_id", user.id);
    }

    const { data: bookings, error } = await query;

    if (error) {
      console.error("Error fetching bookings:", error);
      return NextResponse.json(
        { error: "Failed to fetch bookings" },
        { status: 500 }
      );
    }

    return NextResponse.json({ bookings });

  } catch (error) {
    console.error("Unexpected error in GET /api/bookings:", error);
    return NextResponse.json(
      { error: "Internal server error" },
      { status: 500 }
    );
  }
}
