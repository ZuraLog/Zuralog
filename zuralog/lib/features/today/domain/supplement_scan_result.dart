library;

/// The result returned by the AI label-scan endpoint.
///
/// All fields are nullable — the AI may not be able to extract every piece of
/// information from a given image or barcode. Callers must check each field
/// before using it.
class SupplementScanResult {
  const SupplementScanResult({
    this.name,
    this.doseAmount,
    this.doseUnit,
    this.form,
    this.confidence,
  });

  /// Parsed product name (e.g. 'Vitamin D3').
  final String? name;

  /// Numeric dose quantity (e.g. 5000.0).
  final double? doseAmount;

  /// Dose unit string (e.g. 'IU', 'mg', 'mcg').
  final String? doseUnit;

  /// Physical form of the supplement (e.g. 'softgel', 'capsule', 'tablet').
  final String? form;

  /// Model confidence score in the range 0.0–1.0.
  final double? confidence;

  factory SupplementScanResult.fromJson(Map<String, dynamic> json) =>
      SupplementScanResult(
        name: json['name'] as String?,
        doseAmount: (json['dose_amount'] as num?)?.toDouble(),
        doseUnit: json['dose_unit'] as String?,
        form: json['form'] as String?,
        confidence: (json['confidence'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        if (name != null) 'name': name,
        if (doseAmount != null) 'dose_amount': doseAmount,
        if (doseUnit != null) 'dose_unit': doseUnit,
        if (form != null) 'form': form,
        if (confidence != null) 'confidence': confidence,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SupplementScanResult &&
          name == other.name &&
          doseAmount == other.doseAmount &&
          doseUnit == other.doseUnit &&
          form == other.form &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(name, doseAmount, doseUnit, form, confidence);

  @override
  String toString() =>
      'SupplementScanResult(name: $name, doseAmount: $doseAmount, '
      'doseUnit: $doseUnit, form: $form)';
}
