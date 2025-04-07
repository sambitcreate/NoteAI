#!/usr/bin/env python3
"""
Script to convert Gemma model to TensorFlow Lite format for iOS.
"""

import os
import argparse
import tensorflow as tf
from transformers import AutoModelForCausalLM, AutoTokenizer

def convert_model_to_tflite(model_name, output_file, quantize=True):
    """
    Convert a Hugging Face Gemma model to TensorFlow Lite format.
    
    Args:
        model_name: Name of the model on Hugging Face (e.g., "google/gemma-3b-4b-it")
        output_file: Path to save the TensorFlow Lite model
        quantize: Whether to quantize the model weights
    """
    print(f"Loading model {model_name}...")
    
    # Load model and tokenizer
    model = AutoModelForCausalLM.from_pretrained(model_name, device_map="auto")
    tokenizer = AutoTokenizer.from_pretrained(model_name)
    
    # Save vocabulary
    vocab_file = os.path.splitext(output_file)[0] + "_vocab.json"
    tokenizer.save_vocabulary(vocab_file)
    
    print(f"Converting model to TensorFlow format...")
    
    # Create a TensorFlow function for the model
    class GemmaTF(tf.Module):
        def __init__(self, model):
            super(GemmaTF, self).__init__()
            self.model = model
        
        @tf.function(input_signature=[
            tf.TensorSpec(shape=[1, None], dtype=tf.int32, name="input_ids")
        ])
        def generate(self, input_ids):
            # Generate text with the model
            outputs = self.model.generate(
                input_ids,
                max_length=512,
                num_return_sequences=1,
                temperature=0.7,
                top_p=0.9,
                do_sample=True
            )
            return {"output_ids": outputs}
    
    # Create TF module
    tf_model = GemmaTF(model)
    
    # Save as SavedModel
    saved_model_path = os.path.splitext(output_file)[0] + "_saved_model"
    tf.saved_model.save(tf_model, saved_model_path)
    
    print(f"Converting SavedModel to TensorFlow Lite...")
    
    # Convert to TensorFlow Lite
    converter = tf.lite.TFLiteConverter.from_saved_model(saved_model_path)
    
    if quantize:
        print("Applying quantization...")
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.target_spec.supported_types = [tf.float16]
    
    tflite_model = converter.convert()
    
    # Save the TFLite model
    with open(output_file, 'wb') as f:
        f.write(tflite_model)
    
    print(f"Model converted and saved to {output_file}")
    print(f"Vocabulary saved to {vocab_file}")

def main():
    parser = argparse.ArgumentParser(description="Convert Gemma model to TensorFlow Lite")
    parser.add_argument("--model", default="google/gemma-3b-4b-it", help="Model name on Hugging Face")
    parser.add_argument("--output", default="gemma-3b-4b-it.tflite", help="Output file path")
    parser.add_argument("--no-quantize", action="store_false", dest="quantize", help="Disable quantization")
    
    args = parser.parse_args()
    
    convert_model_to_tflite(args.model, args.output, args.quantize)

if __name__ == "__main__":
    main()
