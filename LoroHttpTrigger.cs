using Microsoft.AspNetCore.Http;
using Microsoft.AspNetCore.Mvc;
using Microsoft.Azure.Functions.Worker;
using Microsoft.Extensions.Logging;
using System.Text.Json;
using System.Globalization;

namespace Loro.Function;

public class LoroHttpTrigger
{
    private readonly ILogger<LoroHttpTrigger> _logger;

    public LoroHttpTrigger(ILogger<LoroHttpTrigger> logger)
    {
        _logger = logger;
    }

    [Function("LoroHttpTrigger")]
    public async Task<IActionResult> Run([HttpTrigger(AuthorizationLevel.Function, "get", "post")] HttpRequest req)
    {
        _logger.LogInformation("C# HTTP trigger function processed a request.");

        string? name = null;
        string? email = null;
        object? age = null;

        // Try to read from JSON body first (if POST)
        if (req.Method == HttpMethods.Post && req.ContentLength > 0)
        {
            try
            {
                var body = await new StreamReader(req.Body).ReadToEndAsync();
                if (!string.IsNullOrWhiteSpace(body))
                {
                    using (JsonDocument doc = JsonDocument.Parse(body))
                    {
                        var root = doc.RootElement;

                        if (root.TryGetProperty("name", out var nameProp) && nameProp.ValueKind != JsonValueKind.Null)
                            name = nameProp.GetString();

                        if (root.TryGetProperty("email", out var emailProp) && emailProp.ValueKind != JsonValueKind.Null)
                            email = emailProp.GetString();

                        if (root.TryGetProperty("age", out var ageProp) && ageProp.ValueKind != JsonValueKind.Null)
                        {
                            if (ageProp.ValueKind == JsonValueKind.Number)
                                age = ageProp.GetInt32();
                            else if (ageProp.ValueKind == JsonValueKind.String)
                                age = ageProp.GetString();
                        }
                    }
                }
            }
            catch (Exception ex)
            {
                _logger.LogWarning($"Failed to parse JSON body: {ex.Message}");
            }
        }

        // Fall back to query string parameters if not found in body
        if (string.IsNullOrWhiteSpace(name))
            name = req.Query["name"];

        if (string.IsNullOrWhiteSpace(email))
            email = req.Query["email"];

        if (age == null && req.Query.ContainsKey("age"))
            age = req.Query["age"].ToString();

        // Apply formatting rules
        var formattedName = FormatName(name);
        var formattedEmail = FormatEmail(email);
        var formattedAge = FormatAge(age);

        var response = new
        {
            name = formattedName,
            email = formattedEmail,
            age = formattedAge
        };

        return new OkObjectResult(response);
    }

    private string FormatName(string? name)
    {
        if (string.IsNullOrWhiteSpace(name))
            return "not provided";

        // Title-case: capitalize first letter of each word
        var textInfo = new CultureInfo("en-US", false).TextInfo;
        return textInfo.ToTitleCase(name.ToLower());
    }

    private string FormatEmail(string? email)
    {
        if (string.IsNullOrWhiteSpace(email))
            return "not provided";

        return email.ToLower();
    }

    private object FormatAge(object? age)
    {
        if (age == null)
            return "not provided";

        if (age is int intAge)
            return intAge;

        if (int.TryParse(age.ToString(), out var parsedAge))
            return parsedAge;

        return "not provided";
    }
}