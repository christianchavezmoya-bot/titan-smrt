"""
Billing & Subscription Service - Python/FastAPI
Handles: Entitlements, Trials, Renewals, Proration, Refunds
Integrations: Stripe, Apple IAP, Google Play Billing, Alipay, WeChat Pay
"""

from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional, Dict, Any
from datetime import datetime, timedelta
from enum import Enum
import logging
import json

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(
    title="Titan Billing & Subscription Service",
    description="Handles subscriptions, payments, and entitlements",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ============ ENUMS ============

class SubscriptionTier(str, Enum):
    FREE = "free"
    PRO = "pro"
    ELITE = "elite"

class SubscriptionStatus(str, Enum):
    ACTIVE = "active"
    TRIALING = "trialing"
    PAST_DUE = "past_due"
    CANCELED = "canceled"
    EXPIRED = "expired"

class PaymentProvider(str, Enum):
    STRIPE = "stripe"
    APPLE_IAP = "apple_iap"
    GOOGLE_PLAY = "google_play"
    ALIPAY = "alipay"
    WECHAT = "wechat"

class SubscriptionDuration(str, Enum):
    MONTHLY = "monthly"
    QUARTERLY = "quarterly"
    YEARLY = "yearly"

# ============ DATA MODELS ============

class SubscriptionPlan(BaseModel):
    id: str
    tier: SubscriptionTier
    duration: SubscriptionDuration
    price: float
    currency: str
    trial_days: int
    features: List[str]

class UserSubscription(BaseModel):
    id: str
    user_id: str
    plan_id: str
    tier: SubscriptionTier
    status: SubscriptionStatus
    provider: PaymentProvider
    provider_customer_id: Optional[str]
    provider_subscription_id: Optional[str]
    current_period_start: datetime
    current_period_end: datetime
    trial_start: Optional[datetime]
    trial_end: Optional[datetime]
    cancel_at_period_end: bool
    created_at: datetime
    updated_at: datetime

class PaymentMethod(BaseModel):
    id: str
    user_id: str
    provider: PaymentProvider
    provider_payment_method_id: str
    type: str  # "card", "apple_pay", "google_pay", etc.
    last_four: Optional[str]
    expiry_month: Optional[int]
    expiry_year: Optional[int]
    is_default: bool

class Invoice(BaseModel):
    id: str
    user_id: str
    subscription_id: str
    amount: float
    currency: str
    status: str  # "draft", "open", "paid", "void", "uncollectible"
    invoice_url: Optional[str]
    invoice_pdf: Optional[str]
    created_at: datetime
    paid_at: Optional[datetime]

class SubscriptionFeatures(BaseModel):
    ai_coach: bool
    advanced_analytics: bool
    custom_workouts: bool
    video_content: bool
    social_features: bool
    nutrition_tracking: bool
    ble_devices: bool
    live_classes: bool
    offline_mode: bool
    priority_support: bool

# ============ TIER FEATURES ============

TIER_FEATURES = {
    SubscriptionTier.FREE: SubscriptionFeatures(
        ai_coach=False,
        advanced_analytics=False,
        custom_workouts=True,
        video_content=True,
        social_features=True,
        nutrition_tracking=False,
        ble_devices=False,
        live_classes=False,
        offline_mode=True,
        priority_support=False,
    ),
    SubscriptionTier.PRO: SubscriptionFeatures(
        ai_coach=True,
        advanced_analytics=True,
        custom_workouts=True,
        video_content=True,
        social_features=True,
        nutrition_tracking=True,
        ble_devices=True,
        live_classes=False,
        offline_mode=True,
        priority_support=False,
    ),
    SubscriptionTier.ELITE: SubscriptionFeatures(
        ai_coach=True,
        advanced_analytics=True,
        custom_workouts=True,
        video_content=True,
        social_features=True,
        nutrition_tracking=True,
        ble_devices=True,
        live_classes=True,
        offline_mode=True,
        priority_support=True,
    ),
}

# ============ PRICING ============

SUBSCRIPTION_PLANS = {
    "pro_monthly": SubscriptionPlan(
        id="pro_monthly",
        tier=SubscriptionTier.PRO,
        duration=SubscriptionDuration.MONTHLY,
        price=9.99,
        currency="USD",
        trial_days=7,
        features=["AI Coach", "Advanced Analytics", "Nutrition Tracking", "BLE Devices"],
    ),
    "pro_yearly": SubscriptionPlan(
        id="pro_yearly",
        tier=SubscriptionTier.PRO,
        duration=SubscriptionDuration.YEARLY,
        price=79.99,
        currency="USD",
        trial_days=7,
        features=["AI Coach", "Advanced Analytics", "Nutrition Tracking", "BLE Devices", "2 months free"],
    ),
    "elite_monthly": SubscriptionPlan(
        id="elite_monthly",
        tier=SubscriptionTier.ELITE,
        duration=SubscriptionDuration.MONTHLY,
        price=19.99,
        currency="USD",
        trial_days=14,
        features=["Everything in Pro", "Live Classes", "Priority Support", "Exclusive Content"],
    ),
    "elite_yearly": SubscriptionPlan(
        id="elite_yearly",
        tier=SubscriptionTier.ELITE,
        duration=SubscriptionDuration.YEARLY,
        price=159.99,
        currency="USD",
        trial_days=14,
        features=["Everything in Pro", "Live Classes", "Priority Support", "Exclusive Content", "2 months free"],
    ),
}

# In-memory storage (replace with database in production)
subscriptions: Dict[str, UserSubscription] = {}
payment_methods: Dict[str, List[PaymentMethod]] = {}
invoices: Dict[str, List[Invoice]] = {}

# ============ API ENDPOINTS ============

@app.get("/")
async def root():
    return {
        "status": "ok",
        "service": "billing-subscription",
        "version": "1.0.0",
    }


@app.get("/health")
async def health_check():
    return {"status": "ok", "service": "billing-subscription"}


# ============ PLAN ENDPOINTS ============

@app.get("/api/v1/billing/plans")
async def get_plans():
    """Get all available subscription plans"""
    return {"plans": list(SUBSCRIPTION_PLANS.values())}


@app.get("/api/v1/billing/plans/{plan_id}")
async def get_plan(plan_id: str):
    """Get a specific plan"""
    plan = SUBSCRIPTION_PLANS.get(plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    return plan


# ============ SUBSCRIPTION ENDPOINTS ============

@app.get("/api/v1/billing/subscriptions/{user_id}")
async def get_subscription(user_id: str):
    """Get user's current subscription"""
    # In production, query from database
    sub = subscriptions.get(user_id)
    if not sub:
        # Return free tier
        return {
            "user_id": user_id,
            "tier": SubscriptionTier.FREE,
            "status": SubscriptionStatus.ACTIVE,
            "features": TIER_FEATURES[SubscriptionTier.FREE].dict(),
        }
    return {
        **sub.dict(),
        "features": TIER_FEATURES[sub.tier].dict(),
    }


@app.post("/api/v1/billing/subscriptions")
async def create_subscription(
    user_id: str,
    plan_id: str,
    provider: PaymentProvider,
    payment_method_id: Optional[str] = None,
    promo_code: Optional[str] = None,
):
    """Create a new subscription"""
    plan = SUBSCRIPTION_PLANS.get(plan_id)
    if not plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    
    # Check if user already has active subscription
    existing = subscriptions.get(user_id)
    if existing and existing.status in [SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING]:
        raise HTTPException(status_code=400, detail="User already has an active subscription")
    
    now = datetime.now()
    trial_end = now + timedelta(days=plan.trial_days) if plan.trial_days > 0 else None
    
    # Calculate period end based on duration
    if plan.duration == SubscriptionDuration.MONTHLY:
        period_end = now + timedelta(days=30)
    elif plan.duration == SubscriptionDuration.QUARTERLY:
        period_end = now + timedelta(days=90)
    else:
        period_end = now + timedelta(days=365)
    
    subscription = UserSubscription(
        id=f"sub_{user_id}",
        user_id=user_id,
        plan_id=plan_id,
        tier=plan.tier,
        status=SubscriptionStatus.TRIALING if trial_end else SubscriptionStatus.ACTIVE,
        provider=provider,
        provider_customer_id=f"cus_{provider.value}_{user_id}",
        provider_subscription_id=f"sub_{provider.value}_{user_id}",
        current_period_start=now,
        current_period_end=period_end,
        trial_start=now if trial_end else None,
        trial_end=trial_end,
        cancel_at_period_end=False,
        created_at=now,
        updated_at=now,
    )
    
    subscriptions[user_id] = subscription
    
    # In production:
    # 1. Create customer in Stripe/Apple/Google
    # 2. Attach payment method
    # 3. Create subscription
    # 4. Handle promo code
    
    logger.info(f"Created subscription for user {user_id}: {plan_id} via {provider}")
    
    return {
        "subscription": subscription,
        "features": TIER_FEATURES[plan.tier].dict(),
    }


@app.post("/api/v1/billing/subscriptions/{user_id}/cancel")
async def cancel_subscription(
    user_id: str,
    immediately: bool = False,
    reason: Optional[str] = None,
):
    """Cancel a subscription"""
    sub = subscriptions.get(user_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    
    if immediately:
        sub.status = SubscriptionStatus.CANCELED
        sub.current_period_end = datetime.now()
    else:
        sub.cancel_at_period_end = True
    
    sub.updated_at = datetime.now()
    
    # In production: Cancel with provider (Stripe/Apple/Google)
    
    logger.info(f"Canceled subscription for user {user_id}: immediately={immediately}, reason={reason}")
    
    return {"subscription": sub}


@app.post("/api/v1/billing/subscriptions/{user_id}/reactivate")
async def reactivate_subscription(user_id: str):
    """Reactivate a canceled subscription"""
    sub = subscriptions.get(user_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    
    if not sub.cancel_at_period_end:
        raise HTTPException(status_code=400, detail="Subscription is not scheduled for cancellation")
    
    sub.cancel_at_period_end = False
    sub.updated_at = datetime.now()
    
    return {"subscription": sub}


@app.post("/api/v1/billing/subscriptions/{user_id}/upgrade")
async def upgrade_subscription(
    user_id: str,
    new_plan_id: str,
):
    """Upgrade/downgrade subscription with proration"""
    sub = subscriptions.get(user_id)
    if not sub:
        raise HTTPException(status_code=404, detail="Subscription not found")
    
    new_plan = SUBSCRIPTION_PLANS.get(new_plan_id)
    if not new_plan:
        raise HTTPException(status_code=404, detail="Plan not found")
    
    old_plan = SUBSCRIPTION_PLANS.get(sub.plan_id)
    
    # Calculate proration
    now = datetime.now()
    days_remaining = (sub.current_period_end - now).days
    days_total = (sub.current_period_end - sub.current_period_start).days
    
    old_value = (old_plan.price / days_total) * days_remaining if old_plan else 0
    new_value = (new_plan.price / days_total) * days_remaining
    proration_amount = new_value - old_value
    
    # Update subscription
    sub.plan_id = new_plan_id
    sub.tier = new_plan.tier
    sub.updated_at = now
    
    logger.info(f"Upgraded subscription for {user_id}: {sub.plan_id} -> {new_plan_id}, proration: ${proration_amount:.2f}")
    
    return {
        "subscription": sub,
        "proration_amount": proration_amount,
        "features": TIER_FEATURES[new_plan.tier].dict(),
    }


# ============ ENTITLEMENT ENDPOINTS ============

@app.get("/api/v1/billing/entitlements/{user_id}")
async def get_entitlements(user_id: str):
    """Get user's current entitlements/feature access"""
    sub = subscriptions.get(user_id)
    
    if not sub or sub.status not in [SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING]:
        tier = SubscriptionTier.FREE
    else:
        tier = sub.tier
    
    return {
        "user_id": user_id,
        "tier": tier,
        "features": TIER_FEATURES[tier].dict(),
    }


@app.post("/api/v1/billing/entitlements/check")
async def check_feature_access(
    user_id: str,
    feature: str,
):
    """Check if user has access to a specific feature"""
    sub = subscriptions.get(user_id)
    
    if not sub or sub.status not in [SubscriptionStatus.ACTIVE, SubscriptionStatus.TRIALING]:
        tier = SubscriptionTier.FREE
    else:
        tier = sub.tier
    
    features = TIER_FEATURES[tier]
    has_access = getattr(features, feature, False)
    
    return {
        "user_id": user_id,
        "feature": feature,
        "has_access": has_access,
        "tier": tier,
        "upgrade_required": None if has_access else SubscriptionTier.PRO,
    }


# ============ PAYMENT METHOD ENDPOINTS ============

@app.get("/api/v1/billing/payment-methods/{user_id}")
async def get_payment_methods(user_id: str):
    """Get user's saved payment methods"""
    methods = payment_methods.get(user_id, [])
    return {"payment_methods": methods}


@app.post("/api/v1/billing/payment-methods")
async def add_payment_method(
    user_id: str,
    provider: PaymentProvider,
    provider_payment_method_id: str,
    type: str,
    last_four: Optional[str] = None,
    expiry_month: Optional[int] = None,
    expiry_year: Optional[int] = None,
    set_default: bool = False,
):
    """Add a new payment method"""
    method = PaymentMethod(
        id=f"pm_{len(payment_methods.get(user_id, [])) + 1}",
        user_id=user_id,
        provider=provider,
        provider_payment_method_id=provider_payment_method_id,
        type=type,
        last_four=last_four,
        expiry_month=expiry_month,
        expiry_year=expiry_year,
        is_default=set_default,
    )
    
    if user_id not in payment_methods:
        payment_methods[user_id] = []
    
    if set_default:
        for m in payment_methods[user_id]:
            m.is_default = False
    
    payment_methods[user_id].append(method)
    
    return {"payment_method": method}


@app.delete("/api/v1/billing/payment-methods/{method_id}")
async def delete_payment_method(user_id: str, method_id: str):
    """Delete a payment method"""
    methods = payment_methods.get(user_id, [])
    methods = [m for m in methods if m.id != method_id]
    payment_methods[user_id] = methods
    
    return {"success": True}


# ============ INVOICE ENDPOINTS ============

@app.get("/api/v1/billing/invoices/{user_id}")
async def get_invoices(user_id: str):
    """Get user's invoice history"""
    user_invoices = invoices.get(user_id, [])
    return {"invoices": user_invoices}


@app.get("/api/v1/billing/invoices/{user_id}/{invoice_id}")
async def get_invoice(user_id: str, invoice_id: str):
    """Get a specific invoice"""
    user_invoices = invoices.get(user_id, [])
    invoice = next((i for i in user_invoices if i.id == invoice_id), None)
    if not invoice:
        raise HTTPException(status_code=404, detail="Invoice not found")
    return invoice


# ============ WEBHOOK ENDPOINTS ============

@app.post("/webhooks/stripe")
async def stripe_webhook(request: Request, background_tasks: BackgroundTasks):
    """Handle Stripe webhooks"""
    payload = await request.body()
    sig_header = request.headers.get("stripe-signature")
    
    # In production: Verify webhook signature
    
    event = json.loads(payload)
    event_type = event.get("type")
    
    logger.info(f"Received Stripe webhook: {event_type}")
    
    # Handle different event types
    if event_type == "invoice.paid":
        background_tasks.add_task(handle_invoice_paid, event["data"]["object"])
    elif event_type == "invoice.payment_failed":
        background_tasks.add_task(handle_payment_failed, event["data"]["object"])
    elif event_type == "customer.subscription.deleted":
        background_tasks.add_task(handle_subscription_deleted, event["data"]["object"])
    elif event_type == "customer.subscription.updated":
        background_tasks.add_task(handle_subscription_updated, event["data"]["object"])
    
    return {"received": True}


@app.post("/webhooks/apple")
async def apple_webhook(request: Request):
    """Handle Apple App Store server notifications"""
    payload = await request.body()
    
    # In production: Verify JWT signature from Apple
    
    notification = json.loads(payload)
    notification_type = notification.get("notification_type")
    
    logger.info(f"Received Apple webhook: {notification_type}")
    
    # Handle different notification types
    # INITIAL_BUY, RENEWAL, INTERACTIVE_RENEWAL, CANCEL, DID_FAIL_TO_RENEW, etc.
    
    return {"status": 200}


@app.post("/webhooks/google")
async def google_webhook(request: Request):
    """Handle Google Play Real-time developer notifications"""
    payload = await request.body()
    
    # In production: Verify JWT signature from Google
    
    notification = json.loads(payload)
    
    logger.info(f"Received Google webhook: {notification.get('subscriptionNotification', {}).get('notificationType')}")
    
    return {"status": 200}


# ============ BACKGROUND HANDLERS ============

async def handle_invoice_paid(invoice_data: Dict):
    """Handle successful payment"""
    user_id = invoice_data.get("customer", "").replace("cus_stripe_", "")
    logger.info(f"Invoice paid for user {user_id}")
    # Update subscription status, send receipt email, etc.


async def handle_payment_failed(invoice_data: Dict):
    """Handle failed payment"""
    user_id = invoice_data.get("customer", "").replace("cus_stripe_", "")
    logger.info(f"Payment failed for user {user_id}")
    # Update subscription status, send dunning email, retry logic


async def handle_subscription_deleted(subscription_data: Dict):
    """Handle subscription cancellation"""
    user_id = subscription_data.get("customer", "").replace("cus_stripe_", "")
    logger.info(f"Subscription deleted for user {user_id}")
    # Update subscription status, revoke access


async def handle_subscription_updated(subscription_data: Dict):
    """Handle subscription update"""
    user_id = subscription_data.get("customer", "").replace("cus_stripe_", "")
    logger.info(f"Subscription updated for user {user_id}")
    # Sync subscription details


# ============ PROMO CODE ENDPOINTS ============

@app.post("/api/v1/billing/promo/validate")
async def validate_promo_code(
    code: str,
    plan_id: str,
):
    """Validate a promo code"""
    # In production: Query promo code database
    
    # Mock promo codes
    promo_codes = {
        "NEWYEAR2026": {"discount_percent": 20, "valid_until": "2026-01-31"},
        "FITNESS50": {"discount_percent": 50, "valid_until": "2026-03-31"},
        "TRIAL30": {"trial_days": 30, "valid_until": "2026-12-31"},
    }
    
    promo = promo_codes.get(code.upper())
    if not promo:
        raise HTTPException(status_code=400, detail="Invalid promo code")
    
    return {
        "code": code,
        "valid": True,
        **promo,
    }


# ============ STARTUP ============

@app.on_event("startup")
async def startup_event():
    logger.info("Billing & Subscription Service starting up...")
    # In production: Initialize Stripe client, verify webhook endpoints


@app.on_event("shutdown")
async def shutdown_event():
    logger.info("Billing & Subscription Service shutting down...")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8084)