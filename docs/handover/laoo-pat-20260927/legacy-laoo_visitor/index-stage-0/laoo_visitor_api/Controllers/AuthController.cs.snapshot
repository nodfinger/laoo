using LaooMeetingApi.Models;
using LaooMeetingApi.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.RateLimiting;
using Microsoft.Data.SqlClient;

namespace LaooMeetingApi.Controllers;

[ApiController]
[Route("api/auth")]
public sealed class AuthController : ControllerBase
{
    private readonly AuthenticationService _authenticationService;
    private readonly PasswordResetService _passwordResetService;
    private readonly ILogger<AuthController> _logger;

    public AuthController(
        AuthenticationService authenticationService,
        PasswordResetService passwordResetService,
        ILogger<AuthController> logger)
    {
        _authenticationService = authenticationService;
        _passwordResetService = passwordResetService;
        _logger = logger;
    }

    [HttpPost("forgot-password")]
    [AllowAnonymous]
    [EnableRateLimiting("authentication")]
    public async Task<IActionResult> ForgotPassword([FromBody] PasswordResetRequest request, CancellationToken cancellationToken)
    {
        try
        {
            await _passwordResetService.RequestAsync(
                request.Username,
                request.ProjectCode,
                HttpContext.Connection.RemoteIpAddress?.ToString(),
                cancellationToken);
        }
        catch (Exception exception)
        {
            _logger.LogWarning(
                exception,
                "Password reset request could not be completed.");
        }

        return Ok(new
        {
            success = true,
            message = "หากข้อมูลถูกต้อง ระบบจะส่งคำแนะนำการตั้งรหัสผ่านใหม่ไปยัง Email"
        });
    }

    [HttpPost("reset-password")]
    [AllowAnonymous]
    [EnableRateLimiting("authentication")]
    public async Task<IActionResult> ResetPassword([FromBody] PasswordResetConfirmRequest request, CancellationToken cancellationToken)
    {
        var success = await _passwordResetService.ConfirmAsync(request.Token, request.NewPassword, cancellationToken);
        return success ? Ok(new { success = true, message = "ตั้งรหัสผ่านใหม่สำเร็จ" }) : BadRequest(new { success = false, message = "Token ไม่ถูกต้องหรือหมดอายุ" });
    }

    [HttpPost("login")]
    [AllowAnonymous]
    [EnableRateLimiting("authentication")]
    public async Task<ActionResult<LoginResponse>> Login(
        [FromBody] LoginRequest request,
        CancellationToken cancellationToken)
    {
        try
        {
            var result = await _authenticationService.LoginAsync(
                request,
                cancellationToken);

            return result.Success ? Ok(result) : Unauthorized(result);
        }
        catch (SqlException exception)
        {
            _logger.LogError(
                exception,
                "Login failed because the authentication database is unavailable.");

            return StatusCode(
                StatusCodes.Status503ServiceUnavailable,
                new
                {
                    success = false,
                    code = "DATABASE_UNAVAILABLE",
                    message = "ระบบไม่สามารถเชื่อมต่อฐานข้อมูลได้ชั่วคราว กรุณาลองใหม่อีกครั้ง"
                });
        }
    }

    [HttpGet("me")]
    [Authorize]
    public IActionResult Me()
    {
        return Ok(new
        {
            success = true,
            claims = User.Claims.Select(x => new
            {
                x.Type,
                x.Value
            })
        });
    }
}
