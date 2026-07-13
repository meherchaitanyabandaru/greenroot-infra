-- Ratings: app feedback, trip/delivery ratings, order ratings

CREATE TABLE public.ratings (
    rating_id      BIGSERIAL PRIMARY KEY,
    rating_type    TEXT NOT NULL CHECK (rating_type IN ('APP', 'TRIP', 'ORDER')),
    rated_by_user_id BIGINT NOT NULL REFERENCES public.users(user_id) ON DELETE CASCADE,

    -- Context references (nullable depending on type)
    order_id       BIGINT REFERENCES public.orders(order_id) ON DELETE SET NULL,
    dispatch_id    BIGINT REFERENCES public.dispatches(dispatch_id) ON DELETE SET NULL,

    -- Overall / app rating
    overall_rating SMALLINT CHECK (overall_rating BETWEEN 1 AND 5),
    would_recommend BOOLEAN,

    -- Trip sub-ratings
    driver_behaviour_rating  SMALLINT CHECK (driver_behaviour_rating BETWEEN 1 AND 5),
    on_time_delivery_rating  SMALLINT CHECK (on_time_delivery_rating BETWEEN 1 AND 5),
    plant_condition_rating   SMALLINT CHECK (plant_condition_rating BETWEEN 1 AND 5),

    -- Order sub-ratings
    plant_quality_rating      SMALLINT CHECK (plant_quality_rating BETWEEN 1 AND 5),
    communication_rating      SMALLINT CHECK (communication_rating BETWEEN 1 AND 5),
    overall_experience_rating SMALLINT CHECK (overall_experience_rating BETWEEN 1 AND 5),
    would_buy_again           BOOLEAN,

    comment    TEXT,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Enforce one app rating per user
CREATE UNIQUE INDEX idx_ratings_app_unique
    ON public.ratings (rated_by_user_id)
    WHERE rating_type = 'APP';

-- Enforce one order rating per user per order
CREATE UNIQUE INDEX idx_ratings_order_unique
    ON public.ratings (rated_by_user_id, order_id)
    WHERE rating_type = 'ORDER' AND order_id IS NOT NULL;

-- Enforce one trip rating per user per dispatch
CREATE UNIQUE INDEX idx_ratings_trip_unique
    ON public.ratings (rated_by_user_id, dispatch_id)
    WHERE rating_type = 'TRIP' AND dispatch_id IS NOT NULL;

-- Query indexes
CREATE INDEX idx_ratings_order_id   ON public.ratings (order_id)    WHERE order_id IS NOT NULL;
CREATE INDEX idx_ratings_dispatch_id ON public.ratings (dispatch_id) WHERE dispatch_id IS NOT NULL;
CREATE INDEX idx_ratings_user_id    ON public.ratings (rated_by_user_id);
