"""
EchoVoice - export the fine-tuned HuBERT checkpoint from the training notebook.

hubert_percept_final.py trains with load_best_model_at_end=True, so after
trainer.train() the best checkpoint is already loaded into trainer.model.
Paste the two lines below (before/after evaluation) so the ./hubert-bcs folder
can be zipped/downloaded from Colab and pointed to by ECHOVOICE_MODEL_DIR when
deploying the backend (see Documentation/README_backend.md).
"""

trainer.save_model("./hubert-bcs")          # weights + config
processor.save_pretrained("./hubert-bcs")   # tokenizer / feature extractor