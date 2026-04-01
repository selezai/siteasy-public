-- Make booking_id nullable so messages can be sent via conversation without a booking
ALTER TABLE messages ALTER COLUMN booking_id DROP NOT NULL;
