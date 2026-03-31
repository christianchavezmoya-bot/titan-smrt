from pydantic import BaseModel, EmailStr

class RegisterRequest(BaseModel):
    email: EmailStr
    password: str
    username: str

class AuthResponse(BaseModel):
    user_id: str
    token: str

class LoginRequest(BaseModel):
    email: EmailStr
    password: str
