using Microsoft.AspNetCore.Mvc;
using System; // necessário para Math.Pow

namespace DotNetMathApi.Controllers
{
    [ApiController]
    [Route("[controller]")]
    public class MathController : ControllerBase
    {
        public record MathRequest(double X, double Y);

        [HttpPost("multiply")]
        public IActionResult Multiply([FromBody] MathRequest request)
        {
            return Ok(new { result = request.X * request.Y });
        }

        [HttpPost("power")]
        public IActionResult Power([FromBody] MathRequest request)
        {
            return Ok(new { result = Math.Pow(request.X, request.Y) });
        }
    }
}

