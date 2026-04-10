namespace ReportRenderer;

/// <summary>
/// Parameter DTO yang dikirim ke report — mirror pattern di production code.
/// </summary>
public record FontReportParameter(string FontName, string OutputPath);
