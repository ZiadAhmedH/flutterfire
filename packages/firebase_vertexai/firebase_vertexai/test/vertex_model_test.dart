// Copyright 2024 Google LLC
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_vertexai/firebase_vertexai.dart';
import 'package:firebase_vertexai/src/vertex_model.dart';
import 'package:flutter_test/flutter_test.dart';

import 'utils/matchers.dart';
import 'utils/stub_client.dart';
import 'vertex_mock.dart';

void main() {
  setupFirebaseVertexAIMocks();
  // ignore: unused_local_variable
  late FirebaseApp app;
  setUpAll(() async {
    // Initialize Firebase
    app = await Firebase.initializeApp();
  });
  group('GenerativeModel', () {
    const defaultModelName = 'some-model';

    (ClientController, GenerativeModel) createModel({
      String modelName = defaultModelName,
      RequestOptions? requestOptions,
      Content? systemInstruction,
      List<Tool>? tools,
      ToolConfig? toolConfig,
    }) {
      final client = ClientController();
      final model = createModelWithClient(
          app: app,
          model: modelName,
          client: client.client,
          systemInstruction: systemInstruction,
          tools: tools,
          toolConfig: toolConfig,
          location: 'us-central1');
      return (client, model);
    }

    test('strips leading "models/" from model name', () async {
      final (client, model) = createModel(
        modelName: 'models/$defaultModelName',
      );
      const prompt = 'Some prompt';
      await client.checkRequest(
        () => model.generateContent([Content.text(prompt)]),
        response: arbitraryGenerateContentResponse,
        verifyRequest: (uri, _) {
          expect(uri.path, endsWith('/models/some-model:generateContent'));
        },
      );
    });

    test('allows specifying a tuned model', () async {
      final (client, model) = createModel(
        modelName: 'tunedModels/$defaultModelName',
      );
      const prompt = 'Some prompt';
      await client.checkRequest(
        () => model.generateContent([Content.text(prompt)]),
        response: arbitraryGenerateContentResponse,
        verifyRequest: (uri, _) {
          expect(uri.path, endsWith('/tunedModels/some-model:generateContent'));
        },
      );
    });

    group('generate unary content', () {
      test('can make successful request', () async {
        final (client, model) = createModel();
        const prompt = 'Some prompt';
        const result = 'Some response';
        final response = await client.checkRequest(
          () => model.generateContent([Content.text(prompt)]),
          verifyRequest: (uri, request) {
            expect(
              uri,
              Uri.parse(
                'https://firebaseml.googleapis.com/v2beta/projects/123/locations/us-central1/publishers/google/models/some-model:generateContent',
              ),
            );
            expect(request, {
              'model': 'models/$defaultModelName',
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            });
          },
          response: {
            'candidates': [
              {
                'content': {
                  'role': 'model',
                  'parts': [
                    {'text': result},
                  ],
                },
              },
            ],
          },
        );
        expect(
          response,
          matchesGenerateContentResponse(
            GenerateContentResponse([
              Candidate(
                Content('model', [TextPart(result)]),
                null,
                null,
                null,
                null,
              ),
            ], null),
          ),
        );
      });

      test('can override safety settings', () async {
        final (client, model) = createModel();
        const prompt = 'Some prompt';
        await client.checkRequest(
          () => model.generateContent(
            [Content.text(prompt)],
            safetySettings: [
              SafetySetting(
                HarmCategory.dangerousContent,
                HarmBlockThreshold.high,
              ),
            ],
          ),
          response: arbitraryGenerateContentResponse,
          verifyRequest: (_, request) {
            expect(request['safetySettings'], [
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_ONLY_HIGH',
              },
            ]);
          },
        );
      });

      test('can override generation config', () async {
        final (client, model) = createModel();
        const prompt = 'Some prompt';
        await client.checkRequest(
          () => model.generateContent([
            Content.text(prompt),
          ], generationConfig: GenerationConfig(stopSequences: ['a'])),
          verifyRequest: (_, request) {
            expect(request['generationConfig'], {
              'stopSequences': ['a'],
            });
          },
          response: arbitraryGenerateContentResponse,
        );
      });

      test('can pass system instructions', () async {
        const instructions = 'Do a good job';
        final (client, model) = createModel(
          systemInstruction: Content.system(instructions),
        );
        const prompt = 'Some prompt';
        await client.checkRequest(
          () => model.generateContent([Content.text(prompt)]),
          verifyRequest: (_, request) {
            expect(request['systemInstruction'], {
              'role': 'system',
              'parts': [
                {'text': instructions},
              ],
            });
          },
          response: arbitraryGenerateContentResponse,
        );
      });

      test('can pass tools and function calling config', () async {
        final (client, model) = createModel(
          tools: [
            Tool(functionDeclarations: [
              FunctionDeclaration(
                'someFunction',
                'Some cool function.',
                Schema(SchemaType.string, description: 'Some parameter.'),
              ),
            ]),
          ],
          toolConfig: ToolConfig(
            functionCallingConfig: FunctionCallingConfig(
              mode: FunctionCallingMode.any,
              allowedFunctionNames: {'someFunction'},
            ),
          ),
        );
        const prompt = 'Some prompt';
        await client.checkRequest(
          () => model.generateContent([Content.text(prompt)]),
          verifyRequest: (_, request) {
            expect(request['tools'], [
              {
                'functionDeclarations': [
                  {
                    'name': 'someFunction',
                    'description': 'Some cool function.',
                    'parameters': {
                      'type': 'STRING',
                      'description': 'Some parameter.',
                    },
                  },
                ],
              },
            ]);
            expect(request['toolConfig'], {
              'functionCallingConfig': {
                'mode': 'ANY',
                'allowedFunctionNames': ['someFunction'],
              },
            });
          },
          response: arbitraryGenerateContentResponse,
        );
      });

      test('can override tools and function calling config', () async {
        final (client, model) = createModel();
        const prompt = 'Some prompt';
        await client.checkRequest(
          () => model.generateContent(
            [Content.text(prompt)],
            tools: [
              Tool(functionDeclarations: [
                FunctionDeclaration(
                  'someFunction',
                  'Some cool function.',
                  Schema(SchemaType.string, description: 'Some parameter.'),
                ),
              ]),
            ],
            toolConfig: ToolConfig(
              functionCallingConfig: FunctionCallingConfig(
                mode: FunctionCallingMode.any,
                allowedFunctionNames: {'someFunction'},
              ),
            ),
          ),
          verifyRequest: (_, request) {
            expect(request['tools'], [
              {
                'functionDeclarations': [
                  {
                    'name': 'someFunction',
                    'description': 'Some cool function.',
                    'parameters': {
                      'type': 'STRING',
                      'description': 'Some parameter.',
                    },
                  },
                ],
              },
            ]);
            expect(request['toolConfig'], {
              'functionCallingConfig': {
                'mode': 'ANY',
                'allowedFunctionNames': ['someFunction'],
              },
            });
          },
          response: arbitraryGenerateContentResponse,
        );
      });
    });

    group('generate content stream', () {
      test('can make successful request', () async {
        final (client, model) = createModel();
        const prompt = 'Some prompt';
        final results = {'First response', 'Second Response'};
        final response = await client.checkStreamRequest(
          () async => model.generateContentStream([Content.text(prompt)]),
          verifyRequest: (uri, request) {
            expect(
              uri,
              Uri.parse(
                'https://firebaseml.googleapis.com/v2beta/projects/123/locations/us-central1/publishers/google/models/some-model:streamGenerateContent',
              ),
            );
            expect(request, {
              'model': 'models/$defaultModelName',
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            });
          },
          responses: [
            for (final result in results)
              {
                'candidates': [
                  {
                    'content': {
                      'role': 'model',
                      'parts': [
                        {'text': result},
                      ],
                    },
                  },
                ],
              },
          ],
        );
        expect(
          response,
          emitsInOrder([
            for (final result in results)
              matchesGenerateContentResponse(
                GenerateContentResponse([
                  Candidate(
                    Content('model', [TextPart(result)]),
                    null,
                    null,
                    null,
                    null,
                  ),
                ], null),
              ),
          ]),
        );
      });

      test('can override safety settings', () async {
        final (client, model) = createModel();
        const prompt = 'Some prompt';
        final responses = await client.checkStreamRequest(
          () async => model.generateContentStream(
            [Content.text(prompt)],
            safetySettings: [
              SafetySetting(
                HarmCategory.dangerousContent,
                HarmBlockThreshold.high,
              ),
            ],
          ),
          verifyRequest: (_, request) {
            expect(request['safetySettings'], [
              {
                'category': 'HARM_CATEGORY_DANGEROUS_CONTENT',
                'threshold': 'BLOCK_ONLY_HIGH',
              },
            ]);
          },
          responses: [arbitraryGenerateContentResponse],
        );
        await responses.drain<void>();
      });

      test('can override generation config', () async {
        final (client, model) = createModel();
        const prompt = 'Some prompt';
        final responses = await client.checkStreamRequest(
          () async => model.generateContentStream([
            Content.text(prompt),
          ], generationConfig: GenerationConfig(stopSequences: ['a'])),
          verifyRequest: (_, request) {
            expect(request['generationConfig'], {
              'stopSequences': ['a'],
            });
          },
          responses: [arbitraryGenerateContentResponse],
        );
        await responses.drain<void>();
      });
    });

    group('count tokens', () {
      test('can make successful request', () async {
        final (client, model) = createModel();
        const prompt = 'Some prompt';
        final response = await client.checkRequest(
          () => model.countTokens([Content.text(prompt)]),
          verifyRequest: (uri, request) {
            expect(
              uri,
              Uri.parse(
                'https://firebaseml.googleapis.com/v2beta/projects/123/locations/us-central1/publishers/google/models/some-model:countTokens',
              ),
            );
            expect(request, {
              'contents': [
                {
                  'role': 'user',
                  'parts': [
                    {'text': prompt},
                  ],
                },
              ],
            });
          },
          response: {'totalTokens': 2},
        );
        expect(response, matchesCountTokensResponse(CountTokensResponse(2)));
      });
    });

    group('embed content', () {
      test('can make successful request', () async {
        final (client, model) = createModel();
        const prompt = 'Some prompt';
        final response = await client.checkRequest(
          () => model.embedContent(Content.text(prompt)),
          verifyRequest: (uri, request) {
            expect(
              uri,
              Uri.parse(
                'https://firebaseml.googleapis.com/v2beta/projects/123/locations/us-central1/publishers/google/models/some-model:embedContent',
              ),
            );
            expect(request, {
              'content': {
                'role': 'user',
                'parts': [
                  {'text': prompt},
                ],
              },
            });
          },
          response: {
            'embedding': {
              'values': [0.1, 0.2, 0.3],
            },
          },
        );
        expect(
          response,
          matchesEmbedContentResponse(
            EmbedContentResponse(ContentEmbedding([0.1, 0.2, 0.3])),
          ),
        );
      });
    });

    test('embed content with reduced output dimensionality', () async {
      final (client, model) = createModel();
      const content = 'Some content';
      const outputDimensionality = 1;
      final embeddingValues = [0.1];

      await client.checkRequest(
          () => model.embedContent(
                Content.text(content),
                outputDimensionality: outputDimensionality,
              ), verifyRequest: (_, request) {
        expect(request,
            containsPair('outputDimensionality', outputDimensionality));
      }, response: {
        'embedding': {'values': embeddingValues},
      });
    });

    group('batch embed contents', () {
      test('can make successful request', () async {
        final (client, model) = createModel();
        const prompt1 = 'Some prompt';
        const prompt2 = 'Another prompt';
        final embedding1 = [0.1, 0.2, 0.3];
        final embedding2 = [0.4, 0.5, 1.6];
        final response = await client.checkRequest(
          () => model.batchEmbedContents([
            EmbedContentRequest(Content.text(prompt1)),
            EmbedContentRequest(Content.text(prompt2)),
          ]),
          verifyRequest: (uri, request) {
            expect(
              uri,
              Uri.parse(
                'https://firebaseml.googleapis.com/v2beta/projects/123/locations/us-central1/publishers/google/models/some-model:batchEmbedContents',
              ),
            );
            expect(request, {
              'requests': [
                {
                  'content': {
                    'role': 'user',
                    'parts': [
                      {'text': prompt1},
                    ],
                  },
                  'model': 'models/$defaultModelName',
                },
                {
                  'content': {
                    'role': 'user',
                    'parts': [
                      {'text': prompt2},
                    ],
                  },
                  'model': 'models/$defaultModelName',
                },
              ],
            });
          },
          response: {
            'embeddings': [
              {'values': embedding1},
              {'values': embedding2},
            ],
          },
        );
        expect(
          response,
          matchesBatchEmbedContentsResponse(
            BatchEmbedContentsResponse([
              ContentEmbedding(embedding1),
              ContentEmbedding(embedding2),
            ]),
          ),
        );
      });
    });
  });
}