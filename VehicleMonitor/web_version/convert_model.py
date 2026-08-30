"""
Convert drowsiness_model.keras to TensorFlow.js format.

Usage:
  1. Install dependency: pip install tensorflow
  2. Run: python convert_model.py
"""

import os
import json
import numpy as np


KERAS_MODEL_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'drowsiness_model.keras')
TFJS_OUTPUT_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'tfjs_model')


def keras_to_tfjs_manual():
    import tensorflow as tf

    print("Loading Keras model from:", KERAS_MODEL_PATH)
    model = tf.keras.models.load_model(KERAS_MODEL_PATH)

    print("\nModel Summary:")
    model.summary()

    input_shape = model.input_shape
    output_shape = model.output_shape
    print("\nInput shape:", input_shape)
    print("Output shape:", output_shape)

    os.makedirs(TFJS_OUTPUT_DIR, exist_ok=True)

    # 1. Extract weights with proper layer-prefixed names
    weight_data = bytearray()
    weights_manifest = []

    for layer in model.layers:
        layer_weights = layer.get_weights()
        if not layer_weights:
            continue

        layer_name = layer.name
        w_names = []
        for w in layer.weights:
            # Extract just the variable name part (kernel, bias, etc.)
            parts = w.name.split('/')
            var_name = parts[-1] if len(parts) > 1 else parts[0]
            w_names.append(f"{layer_name}/{var_name}")

        for w_val, w_name in zip(layer_weights, w_names):
            w_val = np.array(w_val, dtype=np.float32)
            weight_entry = {
                "name": w_name,
                "shape": list(w_val.shape),
                "dtype": "float32"
            }
            weights_manifest.append(weight_entry)
            weight_data.extend(w_val.tobytes())

    # Write binary weight file
    weight_filename = "group1-shard1of1.bin"
    weight_path = os.path.join(TFJS_OUTPUT_DIR, weight_filename)
    with open(weight_path, 'wb') as f:
        f.write(bytes(weight_data))

    print("\nWeights written:", weight_filename, f"({len(weight_data) / 1024:.1f} KB)")

    # 2. Build TF.js-compatible model topology (Keras 2 style)
    layers_config = []

    for i, layer in enumerate(model.layers):
        lc = build_tfjs_layer_config(layer, i, input_shape)
        layers_config.append(lc)

    model_json = {
        "format": "layers-model",
        "generatedBy": "CeylonTourMate converter",
        "convertedBy": "Manual Keras-to-TFJS v2",
        "modelTopology": {
            "class_name": "Sequential",
            "config": {
                "name": "sequential",
                "layers": layers_config
            },
            "keras_version": "2.15.0",
            "backend": "tensorflow"
        },
        "weightsManifest": [{
            "paths": [weight_filename],
            "weights": weights_manifest
        }]
    }

    model_json_path = os.path.join(TFJS_OUTPUT_DIR, "model.json")
    with open(model_json_path, 'w') as f:
        json.dump(model_json, f, indent=2)

    print("Model JSON written: model.json")
    print("\nConversion complete!")
    print("Output:", TFJS_OUTPUT_DIR)
    for fname in os.listdir(TFJS_OUTPUT_DIR):
        size = os.path.getsize(os.path.join(TFJS_OUTPUT_DIR, fname))
        print(f"  - {fname} ({size / 1024:.1f} KB)")


def build_tfjs_layer_config(layer, index, model_input_shape):
    """Build TF.js-compatible layer config (Keras 2 style, no 'module' fields)."""
    import tensorflow as tf

    name = layer.name
    class_name = layer.__class__.__name__

    if class_name == 'Conv2D':
        config = {
            "name": name,
            "trainable": True,
            "dtype": "float32",
            "filters": layer.filters,
            "kernel_size": list(layer.kernel_size),
            "strides": list(layer.strides),
            "padding": layer.padding,
            "data_format": layer.data_format,
            "dilation_rate": list(layer.dilation_rate),
            "groups": layer.groups,
            "activation": layer.activation.__name__ if hasattr(layer.activation, '__name__') else str(layer.activation),
            "use_bias": layer.use_bias,
            "kernel_initializer": {"class_name": "GlorotUniform", "config": {"seed": None}},
            "bias_initializer": {"class_name": "Zeros", "config": {}},
            "kernel_regularizer": None,
            "bias_regularizer": None,
            "activity_regularizer": None,
            "kernel_constraint": None,
            "bias_constraint": None
        }
        # First layer needs batch_input_shape
        if index == 0:
            config["batch_input_shape"] = list(model_input_shape)

    elif class_name == 'MaxPooling2D':
        config = {
            "name": name,
            "trainable": True,
            "dtype": "float32",
            "pool_size": list(layer.pool_size),
            "padding": layer.padding,
            "strides": list(layer.strides),
            "data_format": layer.data_format
        }

    elif class_name == 'Flatten':
        config = {
            "name": name,
            "trainable": True,
            "dtype": "float32",
            "data_format": "channels_last"
        }

    elif class_name == 'Dense':
        config = {
            "name": name,
            "trainable": True,
            "dtype": "float32",
            "units": layer.units,
            "activation": layer.activation.__name__ if hasattr(layer.activation, '__name__') else str(layer.activation),
            "use_bias": layer.use_bias,
            "kernel_initializer": {"class_name": "GlorotUniform", "config": {"seed": None}},
            "bias_initializer": {"class_name": "Zeros", "config": {}},
            "kernel_regularizer": None,
            "bias_regularizer": None,
            "kernel_constraint": None,
            "bias_constraint": None
        }

    elif class_name == 'Dropout':
        config = {
            "name": name,
            "trainable": True,
            "dtype": "float32",
            "rate": float(layer.rate),
            "noise_shape": None,
            "seed": None
        }

    else:
        # Generic fallback
        config = {"name": name, "trainable": True, "dtype": "float32"}

    return {"class_name": class_name, "config": config}


if __name__ == '__main__':
    keras_to_tfjs_manual()
