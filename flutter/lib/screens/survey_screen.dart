import '../sync.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../contract/contract.dart';
import '../location.dart';
import '../providers.dart';

class SurveyScreen extends ConsumerStatefulWidget {
  const SurveyScreen({super.key, required this.id});

  final String id;

  @override
  ConsumerState<SurveyScreen> createState() => _SurveyScreenState();
}

class _SurveyScreenState extends ConsumerState<SurveyScreen> {
  final _formKey = GlobalKey<FormState>();
  final Map<String, TextEditingController> _text = {};

  late final Entrance _entrance;
  late bool _coordsConfirmed;
  late bool _addressConfirmed;
  late bool _groundFloorCommercial;

  Map<String, String> _ruleErrors = {};
  bool _saving = false;
  bool _locating = false;
  String? _saveError;

  void _init(Entrance e) {
    _entrance = e;
    _coordsConfirmed = e.coordsConfirmed;
    _addressConfirmed = e.addressConfirmed;
    _groundFloorCommercial = e.groundFloorCommercial ?? false;

    String s(Object? value) => value == null ? '' : '$value';

    _text.addAll({
      'correctedLat': TextEditingController(text: s(e.correctedLat)),
      'correctedLng': TextEditingController(text: s(e.correctedLng)),
      'street': TextEditingController(text: e.street),
      'number': TextEditingController(text: e.number),
      'entranceName': TextEditingController(text: e.entranceName),
      'stories': TextEditingController(text: s(e.stories)),
      'flats': TextEditingController(text: s(e.flats)),
      'elevators': TextEditingController(text: s(e.elevators)),
      'yearBuilt': TextEditingController(text: s(e.yearBuilt)),
      'comment': TextEditingController(text: e.comment ?? ''),
    });
  }

  @override
  void dispose() {
    for (final controller in _text.values) {
      controller.dispose();
    }
    super.dispose();
  }

  int? _int(String key) => int.tryParse(_text[key]!.text.trim());

  double? _double(String key) => double.tryParse(_text[key]!.text.trim());

  Entrance _candidate() => Entrance(
    id: _entrance.id,
    createdAt: _entrance.createdAt,
    updatedAt: _entrance.updatedAt,
    buildingId: _entrance.buildingId,
    lat: _entrance.lat,
    lng: _entrance.lng,
    street: _text['street']!.text.trim(),
    number: _text['number']!.text.trim(),
    entranceName: _text['entranceName']!.text.trim(),
    coordsConfirmed: _coordsConfirmed,
    correctedLat: _coordsConfirmed ? null : _double('correctedLat'),
    correctedLng: _coordsConfirmed ? null : _double('correctedLng'),
    addressConfirmed: _addressConfirmed,
    stories: _int('stories'),
    flats: _int('flats'),
    elevators: _int('elevators'),
    yearBuilt: _int('yearBuilt'),
    groundFloorCommercial: _groundFloorCommercial,
    comment: _text['comment']!.text.trim().isEmpty
        ? null
        : _text['comment']!.text.trim(),
    surveyStatus: _entrance.surveyStatus,
    surveyedBy: _entrance.surveyedBy,
    surveyedAt: _entrance.surveyedAt,
  );

  Future<void> _usePosition() async {
    setState(() {
      _locating = true;
      _saveError = null;
    });

    try {
      final fix = await locate(context, ref);
      if (!mounted) return;

      if (fix == null) {
        setState(() => _saveError = 'Location: not allowed');
        return;
      }

      _text['correctedLat']!.text = fix.lat.toStringAsFixed(5);
      _text['correctedLng']!.text = fix.lng.toStringAsFixed(5);
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = 'Could not get location: $error');
      }
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  Future<void> _submit() async {
    if (_saving) return;

    final fieldsOk = _formKey.currentState!.validate();
    final candidate = _candidate();

    final rules = <String, String>{
      for (final error in validateEntranceSurvey(candidate))
        error.split(':').first: error.split(': ').skip(1).join(': '),
    };

    setState(() {
      _ruleErrors = rules;
      _saveError = null;
    });

    if (!fieldsOk || rules.isNotEmpty) return;

    setState(() => _saving = true);

    try {
      await ref
          .read(databaseProvider)
          .submitSurvey(candidate, ref.read(meProvider));
      pushSurveys(ref);

      try {
        await HapticFeedback.mediumImpact();
      } catch (_) {
        // Salvarea ramane valida daca vibratia nu este disponibila.
      }

      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _saveError = 'Could not save survey: $error');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _field(
    String key,
    String label,
    String? Function(String?) validator, {
    TextInputType? keyboard,
  }) => TextFormField(
    controller: _text[key],
    decoration: InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
    ),
    keyboardType: keyboard,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    validator: validator,
  );

  String? Function(String?) _intRule(String? Function(int?) rule) =>
      (s) => (s ?? '').trim().isNotEmpty && int.tryParse(s!.trim()) == null
      ? 'A whole number'
      : rule(int.tryParse((s ?? '').trim()));

  String? Function(String?) _coordRule(String? Function(num?) rule) =>
      (s) => (s ?? '').trim().isEmpty
      ? null
      : rule(double.tryParse(s!.trim()) ?? double.nan);

  @override
  Widget build(BuildContext context) {
    final found = ref.watch(entranceProvider(widget.id));

    if (_text.isEmpty) {
      if (found.isLoading) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
      }

      if (found.hasError) {
        return Scaffold(
          appBar: AppBar(title: const Text('Survey')),
          body: Center(child: Text('Could not load entrance: ${found.error}')),
        );
      }

      final e = found.value;
      if (e == null) {
        return const Scaffold(body: Center(child: Text('No such entrance.')));
      }

      _init(e);
    }

    const gap = SizedBox(height: 14);
    const number = TextInputType.number;
    const decimal = TextInputType.numberWithOptions(
      decimal: true,
      signed: true,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Survey')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            SwitchListTile(
              title: const Text('The pin is at the door'),
              subtitle: _ruleError('coordsConfirmed'),
              value: _coordsConfirmed,
              onChanged: (value) => setState(() => _coordsConfirmed = value),
            ),
            if (!_coordsConfirmed) ...[
              _field(
                'correctedLat',
                'Corrected latitude',
                _coordRule(validateLat),
                keyboard: decimal,
              ),
              gap,
              _field(
                'correctedLng',
                'Corrected longitude',
                _coordRule(validateLng),
                keyboard: decimal,
              ),
              if (_ruleErrors['correctedLng'] != null)
                _ruleError('correctedLng')!,
              const SizedBox(height: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _locating ? null : _usePosition,
                child: Text(_locating ? 'Finding you...' : 'Use my position'),
              ),
              gap,
            ],
            _field('street', 'Street', validateStreet),
            gap,
            _field('number', 'Number', validateStreetNumber),
            gap,
            _field('entranceName', 'Entrance', validateEntranceName),
            SwitchListTile(
              title: const Text('I checked the address'),
              subtitle: _ruleError('addressConfirmed'),
              value: _addressConfirmed,
              onChanged: (value) => setState(() => _addressConfirmed = value),
            ),
            _field(
              'stories',
              'Stories',
              _intRule(validateStories),
              keyboard: number,
            ),
            gap,
            _field('flats', 'Flats', _intRule(validateFlats), keyboard: number),
            gap,
            _field(
              'elevators',
              'Elevators',
              _intRule(validateElevators),
              keyboard: number,
            ),
            gap,
            _field(
              'yearBuilt',
              'Year built',
              _intRule(validateYearBuilt),
              keyboard: number,
            ),
            SwitchListTile(
              title: const Text('Shops on the ground floor'),
              value: _groundFloorCommercial,
              onChanged: (value) =>
                  setState(() => _groundFloorCommercial = value),
            ),
            TextFormField(
              controller: _text['comment'],
              decoration: const InputDecoration(
                labelText: 'Comment',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: validateFreeText,
            ),
            gap,
            if (_saveError != null) ...[
              Text(
                _saveError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              gap,
            ],
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              onPressed: _saving || _locating ? null : _submit,
              child: Text(_saving ? 'Saving...' : 'Submit survey'),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _ruleError(String key) {
    final message = _ruleErrors[key];
    if (message == null) return null;

    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
